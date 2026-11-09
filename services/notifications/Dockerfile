FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3002

COPY package*.json ./
COPY src ./src

USER node
EXPOSE 3002

HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD node -e "fetch('http://localhost:3002/health').then(r=>r.ok?process.exit(0):process.exit(1)).catch(()=>process.exit(1))"

CMD ["node", "src/index.js"]
