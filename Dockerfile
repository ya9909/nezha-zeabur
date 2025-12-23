FROM ubuntu:22.04

# 1. 更新系统并安装必要工具
# 包含 supervisor (进程管理), curl/wget (下载), unzip, ca-certificates (HTTPS证书)
RUN apt-get update && \
    apt-get install -y curl wget unzip supervisor ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. 设置工作目录
WORKDIR /app

# 3. 下载哪吒面板 (Dashboard)
# 直接从 GitHub Releases 下载最新版二进制文件
RUN wget -O /app/dashboard https://github.com/naiba/nezha/releases/latest/download/dashboard-linux-amd64 && \
    chmod +x /app/dashboard

# 4. 下载 Cloudflared (隧道)
RUN wget -O /app/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    chmod +x /app/cloudflared

# 5. 创建数据目录
RUN mkdir -p /app/data

# 6. 生成 Supervisor 配置文件
# 这里定义了两个服务：nezha (面板) 和 cloudflared (隧道)
# 关键：使用环境变量 (ENV_...) 来动态填入密钥，确保安全
RUN printf "[supervisord]\n\
nodaemon=true\n\
logfile=/dev/null\n\
pidfile=/var/run/supervisord.pid\n\
\n\
[program:nezha]\n\
command=/app/dashboard\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stderr_logfile=/dev/stderr\n\
environment=NZ_SERVER_PORT=\"8008\",NZ_GRPC_PORT=\"5555\",NZ_GitHub_OAuth_ClientID=\"%%(ENV_GH_CLIENT_ID)s\",NZ_GitHub_OAuth_ClientSecret=\"%%(ENV_GH_CLIENT_SECRET)s\",NZ_ADMIN_LOGINS=\"%%(ENV_NZ_ADMIN)s\",NZ_LANGUAGE=\"zh-CN\"\n\
\n\
[program:cloudflared]\n\
command=/app/cloudflared tunnel run --token %%(ENV_CF_TOKEN)s\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stderr_logfile=/dev/stderr\n" > /etc/supervisor/conf.d/supervisord.conf

# 7. 暴露端口
EXPOSE 8008 5555

# 8. 启动命令
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
