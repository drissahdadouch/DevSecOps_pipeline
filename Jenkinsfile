pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION = "us-east-1"
        SONAR_SCANNER_HOME = tool 'sonarqube-scanner702';
    }
    stages {
        stage("check dependency"){
            parallel{
                
             stage('NPM Dependency Audit') {
                    steps {
                        dir('Web_app/frontend'){
                        sh '''
                            npm audit --audit-level=critical
                            echo $?
                        '''
                        }
                        dir('Web_app/backend'){
                        sh '''
                            npm audit --audit-level=critical
                            echo $?
                        '''
                        }
                    }
                }
        
        stage("owasp_check"){
            steps{
               dir('Web_app'){
                dependencyCheck additionalArguments: '--format ALL', odcInstallation: 'owasp_dependency_check'
               }
                }
               
              }
           }
        }
     /*   stage("code quality testing with sonarqube"){
            steps{
                sh'''
                $SONAR_SCANNER_HOME/bin/sonar-scanner \
                   -Dsonar.projectKey=pfa_pipeline \
                   -Dsonar.sources=. \
                   -Dsonar.host.url=http://127.0.0.1:9000 \
                   -Dsonar.javascript.lcov.reportPaths=./coverage/lcov.info \
                   -Dsonar.token=sqp_c938e562bcb28ee470127ee0165685b15d6ffd0c
                '''
            }
        }  */
         stage("Build Docker images"){
            steps{
                dir('Web_app/frontend'){
                    sh ''' 
                    docker build -t drissahd/frontend_app .
                    '''
                }
                dir('Web_app/backend'){
                  sh ''' 
                    docker build -t drissahd/backend_app .
                    '''  
                }
            }
        }
        stage("scanning docker images with trivy"){
            steps{
                sh '''
                trivy image  --severity HIGH,CRITICAL --format template --template "@/usr/local/share/trivy/templates/html.tpl" -o trivy-scan-frontend-report.html drissahd/frontend_app
                
                trivy image  --severity HIGH,CRITICAL --format template --template "@/usr/local/share/trivy/templates/html.tpl" -o trivy-scan-backend-report.html drissahd/backend_app
               '''
            }
        }
         stage("push docker images to Dockerhub"){
            steps{
                withDockerRegistry(credentialsId: 'Dockerhub_token', url: 'https://index.docker.io/v1/'){
               sh' docker push drissahd/frontend_app'
               sh' docker push drissahd/backend_app'
              }
            }
        } 
        stage("Create an EKS Cluster") {
            steps {
                script {
                    dir('cloud_infra') {
                        sh "terraform init"
                        sh "terraform apply -auto-approve"
                        sh "terraform destroy"
                    }
                }
            }
        }
        stage("Deploy to EKS") {
            steps {
                script {
                    dir('k8s') {
                        sh "aws eks update-kubeconfig --name my-eks-cluster"
                        dir('Rbac'){
                        sh "kubectl apply -f ClusterRole.yaml" 
                        sh "kubectl apply -f ClusterRoleBinding.yaml"  
                        }
                        dir('Autoscaling'){
                        /* HPA Custom Resource Definitions */
                        sh "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml "
                        /* VPA Custom Resource Definitions */
                        sh '''
                          kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml
                          kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-rbac.yaml
                          kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/recommender-deployment.yaml
                          kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/updater-deployment.yaml
                          kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/admission-controller-deployment.yaml
                        '''
                        sh "kubectl apply -f HPA.yaml"
                        sh "kubectl apply -f VPA.yaml"
                        }
                        dir('deployment'){
                        sh "kubectl apply -f web_app_deployment.yaml"
                        sh "kubectl apply -f web_app_service.yaml"
                        sh "kubectl get service frontend-app"
                        }
                    }
                }
            }
        } 
    }
}
