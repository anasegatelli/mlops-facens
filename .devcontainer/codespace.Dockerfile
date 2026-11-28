# Monta o Codespace (o ambiente de trabalho), não a imagem da API: essa é o Dockerfile da raiz (Aula 2, T2).
FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

# O repositório do Yarn que vem nesta imagem está com a chave vencida (NO_PUBKEY 62D54FD4003F6525)
# e quebra o apt-get update da feature docker-in-docker. O Yarn não é usado na disciplina.
RUN rm -f /etc/apt/sources.list.d/yarn*
