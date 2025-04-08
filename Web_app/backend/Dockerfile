FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install --production

COPY . .

FROM node:20-slim

WORKDIR /app

COPY --from=builder /app .
EXPOSE 5000
RUN npm install --only=production

CMD ["npm", "start"]
