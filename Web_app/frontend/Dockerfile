FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install  --force
COPY . .
RUN npm run build  # Commande pour construire l'application Next.js

FROM node:20-alpine

WORKDIR /app
COPY --from=builder /app .
EXPOSE 3000
CMD ["npm", "start"]
