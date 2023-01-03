# build
FROM node:14.17.3 as builder
# Create app directory
WORKDIR /usr/src/app
COPY . .
RUN npm install
RUN npm run build

# release
FROM nginx:1.21.6-alpine
COPY --from=builder /usr/src/app/dist/frontend /usr/share/nginx/html
EXPOSE 8080
