# Docker: material complementar

Este material explica o que é o Docker, como instalá-lo, como trabalhar com imagens e containers e como empacotar a API de previsão (do material de FastAPI) numa imagem que roda igual em qualquer máquina.

Os exemplos usam o mesmo caso dos outros materiais: a **API de previsão de vendas diárias** de uma rede de lojas, que carrega o modelo `vendas-diarias` do MLflow.

> [!TIP]
> Documentação oficial:
>
> - Visão geral do Docker: <https://docs.docker.com/get-started/docker-overview/>
> - Referência do Dockerfile: <https://docs.docker.com/reference/dockerfile/>
> - Docker Compose: <https://docs.docker.com/compose/>
> - Docker Hub (catálogo de imagens): <https://hub.docker.com/>
>
> Para estudar mais: a playlist *Descomplicando Docker*, da LINUXtips (em português): <https://www.youtube.com/playlist?list=PLf-O3X2-mxDn1VpyU2q3fuI6YYeIWp5rR>

---

## 1. O que é o Docker

O **Docker** é uma plataforma open source para empacotar uma aplicação junto com tudo de que ela precisa (versão do Python, bibliotecas, arquivos de configuração) numa unidade chamada **container**.

Um container funciona como uma caixa fechada: o que roda dentro dele roda da mesma forma no seu computador, no Codespace, no computador de um colega ou num servidor de produção. Isso acaba com o clássico "na minha máquina funciona".

### 1.1 Container não é máquina virtual

Uma máquina virtual simula um computador inteiro, com o próprio sistema operacional. Um container é mais leve: ele usa o **núcleo (kernel) do sistema operacional da máquina hospedeira** e isola apenas os processos, os arquivos e a rede da aplicação. Por isso o Docker é chamado de virtualização *no nível do sistema operacional*.

| | Máquina virtual | Container |
|---|---|---|
| O que leva | Sistema operacional completo + aplicação | Só a aplicação e suas dependências |
| Tamanho típico | Gigabytes | Megabytes a poucos gigabytes |
| Tempo para iniciar | Minutos | Segundos |
| Isolamento | Total (outro sistema operacional) | De processos, arquivos e rede; o kernel é compartilhado |

### 1.2 Por que usar Docker em Machine Learning

Em Ciência de Dados, reproduzir um ambiente é um dos maiores desafios. O Docker ajuda em quatro frentes:

- **Isolamento de ambiente:** projetos com versões diferentes de Python e de bibliotecas convivem na mesma máquina sem conflito.
- **Dependências complexas:** imagens prontas (com Python, drivers de GPU, bancos de dados) poupam horas de configuração.
- **Portabilidade do modelo:** a mesma imagem que você testa no Codespace é a que vai para a nuvem servir previsões, com o mesmo comportamento.
- **Escalabilidade:** como cada container é idêntico, dá para rodar várias cópias da mesma API para atender mais requisições. Ferramentas chamadas orquestradores (como o Kubernetes) automatizam isso; elas estão fora do escopo da disciplina.

---

## 2. Imagens, camadas e containers

Para trabalhar com Docker, é fundamental entender a diferença entre **imagem** e **container**.

Uma analogia da programação: a imagem é como uma **classe**, e o container é como um **objeto** criado a partir dela. Da mesma imagem saem quantos containers você quiser.

### 2.1 Imagem

Uma **imagem** é um pacote **somente leitura** com tudo o que é necessário para rodar a aplicação: sistema base, Python, bibliotecas, código, variáveis de ambiente e o comando de inicialização.

- **É construída** a partir de um arquivo de instruções, o `Dockerfile` (seção 5).
- **É imutável:** depois de criada, não muda. Se o código mudar, você constrói uma imagem nova.
- **É portátil:** pode ser enviada para um **registro** (*registry*) e baixada em outra máquina.

### 2.2 Camadas e cache

Cada imagem é formada por **camadas** (*layers*) empilhadas. Cada instrução do `Dockerfile` que altera arquivos gera uma camada.

Uma imagem também costuma ser construída sobre outra. A imagem da API, por exemplo, parte de uma imagem com Python, que por sua vez parte de uma imagem enxuta de Linux:

```
┌─────────────────────────────┐
│  código da API              │  ← sua camada (muda sempre)
├─────────────────────────────┤
│  bibliotecas (pip install)  │  ← sua camada (muda pouco)
├─────────────────────────────┤
│  Python 3.12                │  ┐
├─────────────────────────────┤  │ imagem base python:3.12-slim
│  Debian enxuto              │  ┘
└─────────────────────────────┘
```

O Docker guarda as camadas em **cache**. Ao construir a imagem de novo, ele reaproveita as camadas que não mudaram e só refaz a partir da primeira que mudou. É isso que torna o segundo build muito mais rápido que o primeiro, desde que o `Dockerfile` esteja na ordem certa (seção 5.2).

### 2.3 Container

Um **container** é uma imagem em execução. Ao iniciar, o Docker coloca por cima das camadas da imagem uma camada fina de **leitura e escrita**, só daquele container. O que o container altera fica nessa camada, e a imagem continua intacta.

- **É isolado:** cada container tem os próprios processos, arquivos e rede, sem interferir nos outros nem na máquina hospedeira.
- **É efêmero:** containers são feitos para serem criados, parados e apagados sem cerimônia. Ao apagar um container, a camada de escrita dele vai junto. Dados que precisam durar (um banco de dados, os runs do MLflow, os dados do DVC) devem ficar fora do container, em **volumes** (seção 7.3) ou em serviços externos.

### 2.4 Registros: Docker Hub e outros

Um **registro** é um serviço que guarda e distribui imagens, como o GitHub faz com código. O mais conhecido é o **Docker Hub** (<https://hub.docker.com/>), onde ficam as imagens oficiais de Python, PostgreSQL, Ubuntu e milhares de outras. Existem outros, como o **GitHub Container Registry** (`ghcr.io`) e os registros das nuvens (AWS, Azure, Google Cloud).

O nome de uma imagem segue o formato `registro/nome:tag`. Quando o registro é omitido, o Docker usa o Docker Hub:

- `python:3.12-slim` → imagem `python` do Docker Hub, tag `3.12-slim`;
- `ghcr.io/mlflow/mlflow:v3.17.0` → imagem do MLflow no GitHub Container Registry.

A **tag** identifica a versão. Sem tag, o Docker usa `latest`.

> [!WARNING]
> Evite `latest` (ou omitir a tag). A versão "mais recente" de hoje não é a de amanhã, e duas pessoas que baixam a mesma imagem em dias diferentes podem acabar com ambientes diferentes. Para ter reprodutibilidade, fixe sempre a tag (`python:3.12-slim`, e não `python`).

---

## 3. Instalação

### 3.1 Na disciplina (Codespaces)

O Codespace da disciplina já vem com o Docker instalado. Confira no terminal:

```bash
docker --version
docker run hello-world
```

### 3.2 No Windows: Docker Desktop com WSL 2

No Windows, a recomendação oficial é o **Docker Desktop**, que traz o Docker Engine, uma interface gráfica e a integração com o WSL 2 (o Linux dentro do Windows). Com essa integração, você usa os comandos do Docker no terminal do Linux (WSL) e o Windows gerencia os recursos da máquina.

Guia oficial: <https://docs.docker.com/desktop/setup/install/windows-install/>

1. Baixe o instalador do Docker Desktop no site do Docker. Escolha a versão do seu processador: **AMD64** (Intel/AMD, a maioria dos computadores) ou **ARM64**.
2. Execute o instalador como administrador. Deixe marcada a opção de usar o **WSL 2** em vez do Hyper-V e clique em **OK**.
3. Ao final, clique em **Close** e reinicie o computador.
4. Abra o Docker Desktop. A primeira inicialização do Docker Engine pode demorar alguns minutos.
5. Vá em **Settings** (engrenagem) → **Resources** → **WSL Integration**.
6. Marque **Enable integration with my default WSL distro**, ative a sua distribuição (por exemplo, Ubuntu) e clique em **Apply & restart**.
7. Feche **todos** os terminais do WSL e abra um novo. O terminal precisa ser reaberto para enxergar o Docker.
8. Teste com `docker run hello-world`.

> [!NOTE]
> O Docker Engine só funciona com o Docker Desktop aberto. Depois de ligar o computador, abra o aplicativo (ou rode `docker desktop start` num terminal do **Windows**). O ícone da baleia na barra de tarefas indica que ele está rodando.

> [!NOTE]
> VPNs podem causar instabilidade no Docker. Se algo falhar sem motivo aparente, tente com a VPN desligada.

### 3.3 No macOS

Instale o **Docker Desktop** (<https://docs.docker.com/desktop/setup/install/mac-install/>), escolhendo a versão do seu processador: **Apple Silicon** (M1, M2...) ou **Intel**. Depois de abrir o aplicativo, os comandos funcionam no Terminal.

### 3.4 No Linux

No Linux (fora do WSL), o Docker Engine pode ser instalado pelo script oficial de conveniência:

```bash
sudo apt update && sudo apt upgrade -y      # Ubuntu/Debian: atualize os pacotes antes
curl -fsSL https://get.docker.com | sh
```

> [!NOTE]
> Se você rodar esse script dentro do WSL, ele mostra o aviso `WSL DETECTED: We recommend using Docker Desktop for Windows` e espera 20 segundos antes de continuar (você pode cancelar com Ctrl + C). No WSL, prefira o Docker Desktop (seção 3.2).

Depois da instalação, os comandos do Docker só funcionam com `sudo`. Sem ele, aparece:

```
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

Para usar o Docker sem `sudo`, adicione o seu usuário ao grupo `docker`:

```bash
sudo usermod -aG docker $USER    # adiciona o usuário atual ao grupo docker
grep docker /etc/group           # confira se o seu usuário aparece na linha
newgrp docker                    # aplica o grupo novo neste terminal
```

Teste:

```bash
docker run hello-world
docker ps
```

Guias oficiais: instalação (<https://docs.docker.com/engine/install/>) e pós-instalação (<https://docs.docker.com/engine/install/linux-postinstall/>).

> [!WARNING]
> Quem está no grupo `docker` tem, na prática, poderes de administrador na máquina. Num computador pessoal tudo bem; num servidor compartilhado, combine com quem administra.

### 3.5 O primeiro container: `hello-world`

Se a instalação deu certo, `docker run hello-world` mostra:

```
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
...
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.
```

A própria mensagem resume o que aconteceu:

1. O comando `docker` (o **cliente**) pediu ao **Docker daemon** (o serviço que faz o trabalho) para rodar a imagem.
2. Como a imagem não estava na máquina, o daemon a **baixou** do Docker Hub (a parte `Pulling`).
3. O daemon **criou um container** a partir da imagem e o executou.
4. A saída do container apareceu no seu terminal.

---

## 4. Trabalhando com imagens e containers

Nesta seção, os comandos começam com `$` só para indicar o terminal; não digite o `$`.

### 4.1 Baixando e listando imagens

Para rodar um script Python, precisamos de uma imagem com Python. As tags disponíveis ficam na página da imagem no Docker Hub (aba *Tags*). Vamos usar a `3.12-slim`, uma versão enxuta do Python 3.12:

```bash
$ docker pull python:3.12-slim
3.12-slim: Pulling from library/python
...
Status: Downloaded newer image for python:3.12-slim
docker.io/library/python:3.12-slim
```

As imagens baixadas ficam na máquina:

```bash
$ docker images
IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
hello-world:latest   f9078146db2e       25.9kB         9.49kB    U
python:3.12-slim     a1b2c3d4e5f6        180MB         45.0MB
```

O `U` (*In Use*) indica que existe algum container criado a partir daquela imagem.

O `docker pull` é opcional: o `docker run` baixa a imagem sozinho quando ela não existe na máquina.

### 4.2 Rodando e listando containers

```bash
$ docker run python:3.12-slim
$ docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

O container rodou e terminou na hora. O comando padrão dessa imagem é o interpretador `python3`, que, sem um terminal conectado, não tem o que fazer e encerra. Por isso o `docker ps`, que lista só os containers **em execução**, vem vazio. Com `-a`, aparecem todos, inclusive os parados:

```bash
$ docker ps -a
CONTAINER ID   IMAGE              COMMAND     CREATED          STATUS                      PORTS     NAMES
c0568a74e7d9   python:3.12-slim   "python3"   49 seconds ago   Exited (0) 47 seconds ago             unruffled_euclid
6025bcdb6598   hello-world        "/hello"    16 hours ago     Exited (0) 16 hours ago               happy_margulis
```

Os nomes (`unruffled_euclid`, `happy_margulis`) são sorteados pelo Docker quando você não escolhe um com `--name`.

### 4.3 Containers interativos: `-it` e `--rm`

Para usar o Python dentro do container, rode no modo interativo:

```bash
$ docker run -it --rm python:3.12-slim
Python 3.12.x (main, ...) [GCC ...] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> def soma10(x: int):
...     return x + 10
...
>>> soma10(3)
13
>>> exit()
```

- `-it` conecta o seu terminal ao container (`-i` mantém a entrada aberta; `-t` cria um terminal).
- `--rm` apaga o container automaticamente quando ele termina.

Enquanto esse container está aberto, um `docker ps` em **outro** terminal mostra ele em execução (`Up About a minute`). Depois do `exit()`, ele some até do `docker ps -a`, por causa do `--rm`.

Note que a mesma imagem gerou vários containers independentes: cada `docker run` cria um novo.

### 4.4 Segundo plano: `-d`

Serviços que ficam no ar (uma API, um banco de dados) rodam em segundo plano com `-d` (*detached*). O terminal fica livre, e o container continua rodando:

```bash
$ docker run -d --name meu-python python:3.12-slim sleep 600
$ docker ps
CONTAINER ID   IMAGE              COMMAND       CREATED         STATUS         PORTS     NAMES
d3838fd1787d   python:3.12-slim   "sleep 600"   5 seconds ago   Up 4 seconds             meu-python
```

O `sleep 600` no fim substitui o comando padrão da imagem: o container fica "dormindo" por 10 minutos, o que dá tempo de explorá-lo.

### 4.5 Olhando por dentro: `exec` e `logs`

Com um container em execução, `docker exec` roda um comando lá dentro. Com `-it ... bash`, você ganha um terminal dentro do container:

```bash
$ docker exec -it meu-python bash
root@d3838fd1787d:/# ls
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
root@d3838fd1787d:/# python --version
Python 3.12.x
root@d3838fd1787d:/# exit
```

> [!NOTE]
> Algumas imagens muito enxutas não têm o `bash`. Nesse caso, use `sh`: `docker exec -it <container> sh`.

O `docker logs` mostra tudo o que o container escreveu na tela. É o primeiro lugar para olhar quando algo dá errado, principalmente com containers em segundo plano:

```bash
$ docker logs meu-python      # tudo o que saiu até agora
$ docker logs -f meu-python   # acompanha em tempo real (Ctrl + C para sair)
```

Para parar e apagar:

```bash
$ docker stop meu-python
$ docker rm meu-python
```

Um container pode ser referenciado pelo nome (`meu-python`) ou pelo ID (`d3838fd1787d`, ou só os primeiros caracteres, como `d38`).

### 4.6 Portas: `-p`

Cada container tem a própria rede. Uma API escutando na porta 8000 **dentro** do container não é acessível de fora até você publicar a porta:

```bash
docker run -p <porta_na_maquina>:<porta_no_container> <imagem>
```

- A **porta na máquina** é a que você acessa (por exemplo, `localhost:8000`).
- A **porta no container** é a que a aplicação escuta lá dentro (costuma estar na documentação da imagem ou na instrução `EXPOSE` do `Dockerfile`).

Vários containers podem escutar na mesma porta interna, desde que cada um seja publicado numa porta diferente da máquina:

```bash
docker run -d -p 8000:8000 --name api-v1 vendas-api:1.0
docker run -d -p 8001:8000 --name api-v2 vendas-api:1.1
```

No Codespace, as portas publicadas aparecem na aba **PORTAS** (PORTS).

> [!TIP]
> O Docker Desktop tem um painel gráfico que lista imagens e containers, mostra logs e o consumo de CPU e memória de cada um. É útil quando há vários containers rodando. Pelo terminal, `docker stats` mostra o mesmo consumo.

---

## 5. O Dockerfile

### 5.1 Estrutura

Quando nenhuma imagem pronta serve (o caso de qualquer aplicação sua), você cria a própria. O **`Dockerfile`** é a receita: um arquivo de texto, sem extensão, com as instruções para montar a imagem, lidas de cima para baixo.

```dockerfile
# 1. Imagem base
FROM <imagem_base>:<tag>

# 2. Pasta de trabalho dentro do container
WORKDIR /<pasta>

# 3. Arquivo de dependências primeiro (aproveita o cache)
COPY <arquivo_de_dependencias> .

# 4. Comandos de instalação
RUN <comando_de_instalacao>

# 5. O resto do código
COPY <origem> <destino>

# 6. Variáveis de ambiente fixas (opcional)
ENV <CHAVE>=<valor>

# 7. Porta em que a aplicação escuta (informativo)
EXPOSE <porta>

# 8. Comando executado quando o container inicia
CMD ["<executavel>", "<argumento1>", "<argumento2>"]
```

| Instrução | O que faz |
|---|---|
| `FROM` | Define a imagem de partida. Todo Dockerfile começa por ela. |
| `WORKDIR` | Define (e cria, se preciso) a pasta onde as instruções seguintes rodam. |
| `COPY` | Copia arquivos da sua máquina para dentro da imagem. |
| `RUN` | Executa um comando **durante o build** (instalar pacotes, por exemplo). |
| `ENV` | Define uma variável de ambiente que fica gravada na imagem. |
| `EXPOSE` | Documenta a porta da aplicação. Não publica nada: quem publica é o `-p` do `docker run`. |
| `CMD` | Define o comando que roda **quando o container inicia**. |

A diferença entre `RUN` e `CMD` costuma confundir: o `RUN` roda uma vez, ao **construir** a imagem; o `CMD` roda toda vez que um container **inicia**.

As imagens do Docker Hub também foram feitas com Dockerfiles, e eles costumam ser públicos. Na página da imagem `python`, por exemplo, dá para ver que a `3.12-slim` parte de uma imagem enxuta do Debian.

### 5.2 A ordem importa: cache de camadas

Como o Docker refaz tudo a partir da primeira camada que mudou, a ordem das instruções define quanto tempo cada build leva. A regra: **o que muda pouco vem antes; o que muda sempre vem depois**.

Por isso o arquivo de dependências é copiado e instalado **antes** do código. Ao mudar uma linha do código, só a última camada é refeita, em segundos. Se o código viesse primeiro, qualquer mudança nele obrigaria a reinstalar todas as bibliotecas.

### 5.3 Construindo a imagem: `docker build`

```bash
docker build -t <nome>:<tag> .
```

- `-t` dá nome e tag à imagem (por exemplo, `vendas-api:1.0`).
- O **ponto final** é obrigatório: é o **contexto** do build, a pasta cujos arquivos o Docker pode usar nos `COPY`. O ponto quer dizer "a pasta atual".

### 5.4 O `.dockerignore`

No início do build, o Docker envia a pasta de contexto inteira para o daemon. O arquivo **`.dockerignore`** (na mesma pasta do `Dockerfile`) diz o que fica de fora, com a mesma sintaxe do `.gitignore`. Ele deixa o build mais rápido e, mais importante, evita que arquivos sensíveis acabem dentro da imagem.

```
.env
.git
.dvc
data
models
mlartifacts
mlflow.db
**/__pycache__
```

> [!WARNING]
> O que entra numa camada fica na imagem para sempre, mesmo que uma instrução posterior apague o arquivo. Uma imagem com o `.env` dentro carrega as suas senhas para qualquer lugar onde ela for publicada. O `.env` vai **sempre** no `.dockerignore`.

### 5.5 Configuração: na imagem ou na execução?

- **`ENV` no Dockerfile:** para o que é fixo e faz parte do ambiente (versões, configurações do sistema). Fica gravado na imagem.
- **Na execução** (`-e`, `--env-file` ou o `environment` do Compose): para o que depende de onde e como o container roda (endereços de servidores, credenciais). Pode mudar sem construir uma imagem nova.

Senhas e tokens **nunca** vão no Dockerfile: entram na execução.

---

## 6. Exemplo: a API de vendas num container

Este exemplo empacota a API do material de FastAPI. A estrutura do repositório:

```
.
├── api/
│   ├── __init__.py
│   └── main.py
├── requirements-api.txt
├── Dockerfile
├── .dockerignore
└── .env              # credenciais do MLflow (fora do Git e fora da imagem)
```

### 6.1 As dependências da imagem

A imagem leva só o que a API usa para **responder**. Ferramentas de treino e de desenvolvimento (DVC, Jupyter, o MLflow completo, pytest) ficam de fora. Para carregar o modelo, basta o **`mlflow-skinny`**, uma versão do MLflow sem o servidor e sem a interface, bem menor:

```
# requirements-api.txt
fastapi==0.162.4
uvicorn==0.54.0
python-dotenv
mlflow-skinny==3.17.0
scikit-learn==1.9.1
pandas==3.0.6
cloudpickle
```

O `scikit-learn` e o `cloudpickle` estão aí porque são o que o modelo precisa para ser carregado. Use as mesmas versões do treino: um modelo salvo com uma versão do scikit-learn pode não carregar (ou se comportar diferente) em outra.

> [!TIP]
> Fixe também a versão do `python-dotenv` e do `cloudpickle`, com as versões que você usa no treino (`pip show cloudpickle`). Uma imagem reprodutível tem todas as versões fixas.

### 6.2 O Dockerfile

```dockerfile
# 1. Imagem base: Python 3.12 num Linux enxuto
FROM python:3.12-slim

# 2. Pasta de trabalho dentro do container
WORKDIR /app

# 3. Dependências primeiro: esta camada só é refeita quando o requirements-api.txt muda
COPY requirements-api.txt .
RUN pip install --no-cache-dir -r requirements-api.txt

# 4. Código por último: é o que mais muda
COPY api/ api/

# 5. Porta em que a API escuta (informativo)
EXPOSE 8000

# 6. Comando que roda quando o container inicia
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Dois detalhes:

- **`--no-cache-dir`:** o `pip` não guarda os pacotes baixados, e a imagem fica menor.
- **`--host 0.0.0.0`:** fora do Docker, o Uvicorn escuta em `127.0.0.1`, que só aceita conexões da própria máquina. Dentro do container, a "própria máquina" é o container, e as requisições que chegam pela porta publicada viriam de fora. O `0.0.0.0` aceita conexões de qualquer origem.

### 6.3 Construir e rodar

```bash
docker build -t vendas-api:1.0 .

docker run -d --name vendas-api -p 8000:8000 --env-file .env vendas-api:1.0
docker logs vendas-api
curl -s localhost:8000/health
```

- `--env-file .env` entrega as variáveis do `.env` ao container **na execução**. A imagem não tem endereço nem senha; quem roda é que fornece.
- Se a API não subir, o `docker logs` mostra o motivo (por exemplo, `Application startup failed` quando o MLflow não está acessível).

Para atualizar a API depois de mudar o código:

```bash
docker build -t vendas-api:1.1 .
docker stop vendas-api && docker rm vendas-api
docker run -d --name vendas-api -p 8000:8000 --env-file .env vendas-api:1.1
```

> [!IMPORTANT]
> Dentro do container, `127.0.0.1` (ou `localhost`) é o **próprio container**, não a sua máquina. Se o `.env` aponta para um MLflow rodando na sua máquina em `http://127.0.0.1:5000`, a API no container não o encontra. Com um servidor MLflow remoto (com endereço na internet) isso não acontece. Para alcançar um serviço da máquina hospedeira, use `--network host` no `docker run` (Linux e Codespaces) ou o endereço `host.docker.internal` (Docker Desktop).

### 6.4 Publicando a imagem

Para que outra máquina rode a mesma imagem, ela é enviada a um registro:

```bash
docker login <registro>                         # autentica (o Docker Hub é o padrão)
docker tag vendas-api:1.0 <usuario>/vendas-api:1.0
docker push <usuario>/vendas-api:1.0
```

Na outra máquina, `docker pull <usuario>/vendas-api:1.0` (ou direto o `docker run`) baixa exatamente a mesma imagem.

---

## 7. Docker Compose

### 7.1 Por que usar

Um sistema real costuma ter vários containers: a API, um servidor do MLflow, um banco de dados. Subir cada um com um `docker run` cheio de opções é trabalhoso e fácil de errar. O **Docker Compose** descreve todos os containers e suas configurações num arquivo YAML, e um comando sobe tudo.

Exemplo: a API de vendas junto com um servidor MLflow próprio.

```yaml
# compose.yaml
services:
  mlflow:
    image: ghcr.io/mlflow/mlflow:v3.17.0
    command: >
      mlflow server --host 0.0.0.0 --port 5000
      --backend-store-uri sqlite:////mlflow/mlflow.db
      --artifacts-destination /mlflow/artifacts
      --allowed-hosts "mlflow:5000,localhost:*,127.0.0.1:*"
    ports:
      - "5000:5000"
    volumes:
      - mlflow-dados:/mlflow          # os runs e os modelos sobrevivem ao container

  api:
    build: .                          # constrói a partir do Dockerfile desta pasta
    ports:
      - "8000:8000"
    environment:
      - MLFLOW_TRACKING_URI=http://mlflow:5000   # o nome do serviço vira endereço
    depends_on:
      - mlflow                        # sobe o mlflow antes da api
    restart: on-failure               # tenta de novo se a api cair (ex.: mlflow ainda subindo)

volumes:
  mlflow-dados:
```

| Chave | O que define |
|---|---|
| `services` | Os containers. Cada chave (`mlflow`, `api`) é o nome do serviço. |
| `image` | A imagem a usar. |
| `build` | A pasta com o `Dockerfile`, quando a imagem é construída localmente. |
| `command` | Substitui o `CMD` da imagem. |
| `ports` | Igual ao `-p` do `docker run`. |
| `environment` / `env_file` | Variáveis de ambiente, uma a uma ou a partir de um arquivo (como o `--env-file`). |
| `volumes` | Pastas ou volumes montados no container (seção 7.3). |
| `depends_on` | A ordem de inicialização. Garante que o container começou, não que o serviço já está pronto. |
| `restart` | O que fazer se o container parar: `no`, `on-failure`, `unless-stopped`, `always`. |

O `--allowed-hosts` do MLflow existe pelo mesmo motivo do script das aulas: o servidor do MLflow 3 recusa endereços que não conhece, e a API vai chamá-lo pelo nome `mlflow`.

### 7.2 Comandos

```bash
docker compose up -d        # constrói o que for preciso e sobe tudo em segundo plano
docker compose ps           # lista os containers do projeto
docker compose logs -f api  # acompanha os logs de um serviço
docker compose down         # para e remove os containers e a rede (os volumes ficam)
```

O nome de cada container segue o padrão `<projeto>-<serviço>-<número>`. O projeto, por padrão, é o nome da pasta: numa pasta `vendas`, o container da API se chama `vendas-api-1`.

> [!NOTE]
> Tutoriais antigos usam `docker-compose` (com hífen, a versão 1, descontinuada) e começam o arquivo com uma chave `version:`. Hoje o comando é `docker compose` (com espaço) e a chave `version` é ignorada. O nome padrão do arquivo é `compose.yaml` (`docker-compose.yml` também é reconhecido).

### 7.3 Volumes

Um **volume** é um espaço de armazenamento gerenciado pelo Docker, fora da camada de escrita do container. No exemplo, os runs e os modelos do MLflow ficam no volume `mlflow-dados`: apagar e recriar o container não perde nada. Só um `docker compose down -v` (ou `docker volume rm`) apaga o volume.

Também é possível montar uma pasta da sua máquina no container (por exemplo, `./dados:/app/dados`), útil para compartilhar arquivos durante o desenvolvimento.

### 7.4 Redes

Cada container tem a própria interface de rede, e o Docker organiza os containers em **redes** virtuais. Containers na mesma rede conversam entre si; containers em redes diferentes, não.

A grande vantagem das redes do Docker é o **DNS interno**: dentro de uma rede, um serviço encontra o outro **pelo nome**, sem precisar saber o IP. No exemplo, a API chama `http://mlflow:5000`.

O Docker já vem com três redes:

```bash
$ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
235943c56f36   bridge    bridge    local
aa655a595347   host      host      local
694e42515570   none      null      local
```

- **`bridge`** (padrão): os containers ficam numa rede isolada da rede física e saem para o mundo pela máquina hospedeira. É o tipo mais comum.
- **`host`**: o container usa a rede da própria máquina, sem isolamento de portas. É o que o `--network host` faz.
- **`none`**: sem rede nenhuma.

Ao rodar `docker compose up`, o Compose:

1. cria uma rede `bridge` só para o projeto (`<projeto>_default`);
2. conecta todos os serviços do arquivo a ela;
3. permite que cada serviço encontre os outros pelo nome.

O nome do projeto (e, portanto, da rede) vem da pasta, mas pode ser definido com `docker compose -p <nome> up`, com a variável `COMPOSE_PROJECT_NAME` num `.env` ou com a chave `name:` no topo do `compose.yaml`.

---

## 8. Comandos mais usados

### Registro

| Comando | O que faz |
|---|---|
| `docker login` | Autentica no registro (Docker Hub por padrão) |
| `docker pull <imagem>:<tag>` | Baixa uma imagem |
| `docker push <imagem>:<tag>` | Envia uma imagem sua ao registro |
| `docker search <termo>` | Procura imagens no Docker Hub (mostra repositórios, não tags) |

### Imagens

| Comando | O que faz |
|---|---|
| `docker images` | Lista as imagens da máquina |
| `docker build -t <nome>:<tag> .` | Constrói uma imagem a partir do `Dockerfile` da pasta atual |
| `docker tag <imagem> <novo-nome>:<tag>` | Dá outro nome ou tag a uma imagem |
| `docker rmi <imagem>` | Apaga uma imagem |

### Containers

| Comando | O que faz |
|---|---|
| `docker run <imagem>` | Cria e inicia um container (baixa a imagem se preciso) |
| `  -it` | Modo interativo, com terminal |
| `  -d` | Em segundo plano |
| `  --name <nome>` | Dá um nome ao container |
| `  --rm` | Apaga o container quando ele terminar |
| `  -p <máquina>:<container>` | Publica uma porta |
| `  -e CHAVE=valor` / `--env-file .env` | Passa variáveis de ambiente |
| `docker ps` / `docker ps -a` | Lista os containers em execução / todos |
| `docker stop <container>` | Para um container |
| `docker start <container>` | Inicia de novo um container parado |
| `docker restart <container>` | Para e inicia |
| `docker rm <container>` | Apaga um container parado |

### Investigação

| Comando | O que faz |
|---|---|
| `docker logs <container>` (`-f` para acompanhar) | Mostra a saída do container |
| `docker exec -it <container> bash` | Abre um terminal dentro de um container em execução |
| `docker inspect <container>` | Mostra todos os detalhes técnicos (rede, variáveis, montagens) em JSON |
| `docker stats` | Consumo de CPU, memória e rede de cada container, em tempo real |

### Redes e volumes

| Comando | O que faz |
|---|---|
| `docker network ls` | Lista as redes |
| `docker network inspect <rede>` | Mostra os containers conectados e seus IPs |
| `docker volume ls` | Lista os volumes |
| `docker system df` | Mostra quanto espaço imagens, containers e volumes ocupam |
| `docker system prune` | Apaga containers parados, redes sem uso e imagens sem nome (pede confirmação) |

### Compose

| Comando | O que faz |
|---|---|
| `docker compose up -d` | Sobe todos os serviços do `compose.yaml` |
| `docker compose ps` | Lista os containers do projeto |
| `docker compose logs -f` | Acompanha os logs de todos os serviços |
| `docker compose down` | Para e remove containers e rede (`-v` remove também os volumes) |

---

## 9. Boas práticas

- Fixe a tag de todas as imagens (`python:3.12-slim`, nunca `latest`) e a versão de todas as bibliotecas.
- Prefira imagens base enxutas (`-slim`): menos tamanho, build mais rápido e menos coisas que podem ter falhas de segurança.
- Ordene o Dockerfile do que muda menos para o que muda mais: dependências antes do código.
- Mantenha um `requirements` só da aplicação, sem ferramentas de treino e de desenvolvimento.
- Use `.dockerignore`, sempre com o `.env` dentro.
- Configuração e segredos entram na execução (`--env-file`, `environment`), nunca na imagem.
- Trate containers como descartáveis: dados que precisam durar vão para volumes ou serviços externos.
- Uma responsabilidade por container: a API num, o MLflow noutro, o banco noutro.
- Dê nomes aos containers (`--name`) e versões às imagens (`vendas-api:1.0`, `vendas-api:1.1`): fica claro o que está rodando e dá para voltar à versão anterior.
- Quando algo falhar, comece pelo `docker logs`.
