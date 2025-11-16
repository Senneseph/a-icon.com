FROM nginx:alpine

# Copy static HTML file
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

# Nginx runs as daemon off by default in the official image
CMD ["nginx", "-g", "daemon off;"]

