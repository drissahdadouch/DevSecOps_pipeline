pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION = 'us-east-1'
        SONAR_SCANNER_HOME = tool 'sonarqube-scanner702'
    }

    stages {

        stage("Check Dependencies") {
            parallel {
                stage('NPM Dependency Audit') {
                    steps {
                        dir('Web_app/frontend') {
                            sh '''
                                npm audit --audit-level=critical
                            '''
                        }
                        dir('Web_app/backend') {
                            sh '''
                                npm audit --audit-level=critical
                            '''
                        }
                    }
                }

                stage("OWASP Check") {
                    steps {
                        dir('Web_app') {
                            dependencyCheck additionalArguments: '--format ALL', odcInstallation: 'owasp_dependency_check'
                        }
                    }
                }
            }
        }

        /*
        stage("Code Quality Testing with SonarQube") {
            steps {
                sh '''
                    $SONAR_SCANNER_HOME/bin/sonar-scanner \
                       -Dsonar.projectKey=pfa_pipeline \
                       -Dsonar.sources=. \
                       -Dsonar.host.url=http://127.0.0.1:9000 \
                       -Dsonar.javascript.lcov.reportPaths=./coverage/lcov.info \
                       -Dsonar.token=sqp_c938e562bcb28ee470127ee0165685b15d6ffd0c
                '''
            }
        }
        */

        stage("Build Docker Images") {
            steps {
                dir('Web_app/frontend') {
                    sh 'docker build -t drissahd/frontend_app .'
                }
                dir('Web_app/backend') {
                    sh 'docker build -t drissahd/backend_app .'
                }
            }
        }

        stage("Scan Docker Images with Trivy") {
            steps {
                sh '''
                    trivy image --severity HIGH,CRITICAL --format template \
                        --template "@/usr/local/share/trivy/templates/html.tpl" \
                        -o trivy-scan-frontend-report.html drissahd/frontend_app

                    trivy image --severity HIGH,CRITICAL --format template \
                        --template "@/usr/local/share/trivy/templates/html.tpl" \
                        -o trivy-scan-backend-report.html drissahd/backend_app
                '''
            }
        }

        stage("Push Docker Images to Docker Hub") {
            steps {
                withDockerRegistry(credentialsId: 'Dockerhub_token', url: 'https://index.docker.io/v1/') {
                    sh 'docker push drissahd/frontend_app'
                    sh 'docker push drissahd/backend_app'
                }
            }
        }

        stage("Create an EKS Cluster") {
            steps {
                dir('cloud_infra') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage("Deploy to EKS") {
            steps {
                dir('k8s') {
                    sh 'aws eks update-kubeconfig --name my-eks-cluster'

                    dir('Rbac') {
                        sh 'kubectl apply -f ClusterRole.yaml'
                        sh 'kubectl apply -f ClusterRoleBinding.yaml'
                    }

                    dir('Autoscaling') {
                        sh 'kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml'

                        sh '''
                            kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml
                            kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-rbac.yaml
                            kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/recommender-deployment.yaml
                            kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/updater-deployment.yaml
                            kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/admission-controller-deployment.yaml
                        '''

                        sh 'kubectl apply -f HPA.yaml'
                        sh 'kubectl apply -f VPA.yaml'
                    }

                    dir('deployment') {
                        sh 'kubectl apply -f web_app_deployment.yaml'
                        sh 'kubectl apply -f web_app_service.yaml'
                        sh 'kubectl get service frontend-app'
                    }
                }
            }
        }

        stage("Get External IP") {
            steps {
                script {
                    def ip = sh(
                        script: '''#!/bin/bash
                        ATTEMPTS=0
                        while [ $ATTEMPTS -lt 30 ]; do
                            IP=$(kubectl get svc frontend-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                            if [ -z "$IP" ]; then
                                echo "Waiting for external IP..."
                                sleep 10
                                ATTEMPTS=$((ATTEMPTS + 1))
                            else
                                echo "$IP"
                                break
                            fi
                        done

                        if [ -z "$IP" ]; then
                            echo "Failed to get external IP after timeout"
                            exit 1
                        fi

                        echo "$IP"
                        ''',
                        returnStdout: true
                    ).trim()

                    echo "Retrieved external IP: ${ip}"
                    env.FRONTEND_IP = ip
                }
            }
        }

        stage("Security Scan with OWASP ZAP") {
            steps {
                script {
                    def target = "http://${env.FRONTEND_IP}:3000"
                    echo "Scanning $target"

                    sh """
                        docker run --rm \
                          -v /var/lib/jenkins:/zap/wrk \
                          -v /var/lib/jenkins:/zap/reports \
                          ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
                          -t $target \
                          -r /zap/reports/zap_report.html
                    """
                }
            }
        }
    }
}
