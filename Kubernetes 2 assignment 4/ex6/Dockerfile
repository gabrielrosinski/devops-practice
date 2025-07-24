FROM nginx:alpine

# Simulate 20-second delay before readiness passes
CMD sh -c "sleep 20 && touch /tmp/ready & nginx -g 'daemon off;'"