FROM nginx:alpine

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf
RUN rm /etc/nginx/nginx.conf

# Copy nginx configuration
COPY interface/nginx.conf /etc/nginx/nginx.conf

# Copy static files
COPY interface/index.html /usr/share/nginx/html/index.html
COPY interface/openapi.yaml /usr/share/nginx/html/openapi.yaml

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]