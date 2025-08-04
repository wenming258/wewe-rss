# ---------- Base Image with Configurable pnpm Version ----------
FROM node:20.16.0-alpine AS base

# 声明可配置的 pnpm 版本，默认 10.14.0
ARG PNPM_VERSION=10.14.0

# pnpm 安装目录配置
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# 使用指定版本安装 pnpm
RUN npm install -g pnpm@"${PNPM_VERSION}"

# ---------- Build Stage ----------
FROM base AS build

# 复制项目到工作目录
COPY . /usr/src/app
WORKDIR /usr/src/app

# 安装依赖（使用 --frozen-lockfile 锁定 lockfile）
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

# 构建项目
RUN pnpm run -r build

# 部署 server 输出（两种数据库方案）
RUN pnpm deploy --filter=server --prod /app
RUN pnpm deploy --filter=server --prod /app-sqlite

# Prisma 生成（PostgreSQL/MySQL/其它）
RUN cd /app && pnpm exec prisma generate

# Prisma 生成（SQLite 版本）
RUN cd /app-sqlite && \
    rm -rf ./prisma && \
    mv prisma-sqlite prisma && \
    pnpm exec prisma generate

# ---------- App Image for SQLite ----------
FROM base AS app-sqlite

# 复制 build 输出
COPY --from=build /app-sqlite /app
WORKDIR /app

EXPOSE 4000

# 运行环境变量（可根据需求调整）
ENV NODE_ENV=production
ENV HOST="0.0.0.0"
ENV SERVER_ORIGIN_URL=""
ENV MAX_REQUEST_PER_MINUTE=60
ENV AUTH_CODE=""
ENV DATABASE_URL="file:../data/wewe-rss.db"
ENV DATABASE_TYPE="sqlite"

# 启动脚本权限
RUN chmod +x ./docker-bootstrap.sh

# 启动命令
CMD ["./docker-bootstrap.sh"]

# ---------- App Image for Default DB (e.g. PostgreSQL) ----------
FROM base AS app

# 复制 build 输出
COPY --from=build /app /app
WORKDIR /app

EXPOSE 4000

# 运行环境变量（可根据需求调整）
ENV NODE_ENV=production
ENV HOST="0.0.0.0"
ENV SERVER_ORIGIN_URL=""
ENV MAX_REQUEST_PER_MINUTE=60
ENV AUTH_CODE=""
ENV DATABASE_URL=""

# 启动脚本权限
RUN chmod +x ./docker-bootstrap.sh

# 启动命令
CMD ["./docker-bootstrap.sh"]
