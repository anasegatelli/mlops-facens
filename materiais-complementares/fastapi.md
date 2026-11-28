# FastAPI: material complementar

Este material explica como transformar um modelo registrado no MLflow num serviço que outros sistemas podem chamar. Ele começa pelo que é uma API, passa pelo FastAPI e pelo Pydantic e termina numa API de previsão completa, com testes.

Os exemplos usam o mesmo caso dos materiais de MLflow e DVC: a **previsão de vendas diárias de uma rede de lojas**, com o modelo `vendas-diarias` no Model Registry. As versões são as da disciplina: **FastAPI 0.162.4**, **Uvicorn 0.54.0** e **MLflow 3.17.0**.

> [!TIP]
> Documentação oficial:
>
> - FastAPI (há tradução para o português): <https://fastapi.tiangolo.com/pt/>
> - Pydantic: <https://docs.pydantic.dev/latest/>
> - Uvicorn: <https://www.uvicorn.org/>
> - HTTP, visão geral (MDN, em português): <https://developer.mozilla.org/pt-BR/docs/Web/HTTP>

---

## 1. O que é uma API

**API** (*Application Programming Interface*) é um contrato que diz como um programa pode pedir algo a outro: o que enviar, em qual formato e o que volta como resposta. Quem pede não precisa saber como o outro lado funciona por dentro, só o contrato.

Uma analogia comum é o restaurante. Você (o **cliente**) não entra na cozinha (o **servidor**): faz o pedido pelo cardápio, o garçom leva até a cozinha e traz o prato de volta. O cardápio é o contrato, e a cozinha pode trocar de cozinheiro sem que você perceba.

### 1.1 APIs web e HTTP

As APIs que vamos construir são **APIs web**: o cliente e o servidor conversam pela rede usando o protocolo **HTTP**, o mesmo do navegador. Cada conversa tem duas partes.

A **requisição** (o pedido), que leva:

- um **método**, que é o verbo: o que se quer fazer;
- uma **rota** (ou caminho), que é o endereço do recurso: `/health`, `/predict`;
- opcionalmente, um **corpo** com dados, quase sempre em **JSON**.

A **resposta**, que traz:

- um **código de status**, um número que resume o resultado;
- um **corpo**, também em JSON.

Os métodos mais usados:

| Método | Uso típico |
|---|---|
| `GET` | Buscar uma informação (não altera nada no servidor) |
| `POST` | Enviar dados para o servidor processar ou criar algo |
| `PUT` | Atualizar algo que já existe |
| `DELETE` | Remover algo |

Os códigos de status que mais aparecem numa API de ML:

| Código | Significado | Quando aparece |
|---|---|---|
| `200` | OK | Deu certo |
| `404` | Not Found | A rota não existe |
| `422` | Unprocessable Content | Os dados enviados não seguem o contrato (campo faltando, tipo errado, valor fora dos limites) |
| `500` | Internal Server Error | Erro no código do servidor |
| `503` | Service Unavailable | O serviço está no ar, mas não consegue atender (por exemplo, o modelo não carregou) |

Regra prática: os códigos **4xx** indicam um problema no pedido (culpa de quem chamou) e os **5xx**, um problema no servidor.

### 1.2 JSON

JSON é o formato de texto em que os dados viajam. Ele lembra um dicionário do Python:

```json
{"loja": 2, "promocao": true, "temperatura": 28.5, "dia_semana": 4, "media_movel": 112.3}
```

### 1.3 Uma requisição na prática

Com a API de vendas no ar (seção 6), uma previsão pelo terminal fica assim:

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"loja": 2, "promocao": true, "temperatura": 28.5, "dia_semana": 4, "media_movel": 112.3}'
```

Resposta (status 200):

```json
{"vendas": 119, "model_version": "1"}
```

### 1.4 Por que servir um modelo por API

Um modelo dentro de um notebook só serve a quem abre o notebook. Exposto por uma API:

- **qualquer sistema pode usá-lo**: um site, um app, um painel, outro serviço, em qualquer linguagem. Basta falar HTTP e JSON;
- **quem consome não precisa** de Python, scikit-learn nem do arquivo do modelo;
- **o modelo pode ser trocado** por uma versão nova sem que os consumidores mudem nada, desde que o contrato continue o mesmo.

---

## 2. O que é o FastAPI

O FastAPI é um framework para construir APIs em Python a partir de *type hints* (as anotações de tipo, como `loja: int`). Ele virou uma escolha comum para servir modelos de ML por quatro motivos:

- **Desempenho:** é construído sobre o Starlette (a parte web) e o Pydantic (a validação), e está entre os frameworks Python mais rápidos.
- **Validação automática:** com o Pydantic, os dados enviados são conferidos (tipos, campos obrigatórios, limites) antes de chegarem ao seu código. Se algo estiver errado, a API responde 422 com a explicação, e o modelo nem é chamado.
- **Documentação automática:** a partir do código, o FastAPI gera uma página interativa (`/docs`) em que dá para ver o contrato e testar cada rota no navegador.
- **Suporte a `async`:** permite atender muitas requisições ao mesmo tempo quando o trabalho é esperar por rede ou disco (veja a nota na seção 4.3).

### 2.1 Instalação

```bash
pip install fastapi==0.162.4 uvicorn==0.54.0
```

O **FastAPI** define a API; o **Uvicorn** é o servidor que a coloca no ar e atende as requisições.

---

## 3. Primeira API

### 3.1 A estrutura base

Uma aplicação FastAPI é uma instância de `FastAPI` mais um conjunto de funções, cada uma ligada a um método e a uma rota por um **decorador**:

```python
# api/main.py
from fastapi import FastAPI

app = FastAPI(title="Primeira API", version="1.0.0")


@app.get("/")
def raiz():
    return {"mensagem": "API no ar"}


@app.get("/health")
def health():
    return {"status": "ok"}
```

O `@` indica um decorador: ele registra a função logo abaixo no FastAPI. `@app.get("/health")` quer dizer "quando chegar um `GET` na rota `/health`, execute esta função". O dicionário devolvido vira o JSON da resposta.

Se a API estiver em `https://vendas.exemplo.com`, a rota `/` responde em `https://vendas.exemplo.com/` e a rota `/health`, em `https://vendas.exemplo.com/health`.

### 3.2 Colocando no ar

```bash
uvicorn api.main:app --port 8000 --reload
```

- `api.main:app` significa "o objeto `app` do arquivo `api/main.py`" (pasta e arquivo separados por ponto, objeto depois dos dois pontos).
- `--reload` reinicia o servidor sempre que um arquivo muda. Use só durante o desenvolvimento.

No Codespace, abra a aba **PORTAS** (PORTS) e clique no 🌐 da porta **8000**. Acrescente `/docs` ao endereço para ver a documentação interativa: em cada rota, **Try it out → Execute** faz uma chamada de verdade. Pelo terminal, `curl localhost:8000/health` faz o mesmo.

### 3.3 Parâmetros na rota e na URL

Uma rota também pode receber valores pelo próprio endereço:

```python
@app.get("/lojas/{loja_id}")
def detalhes_da_loja(loja_id: int, com_historico: bool = False):
    return {"loja": loja_id, "com_historico": com_historico}
```

- `loja_id` é um **parâmetro de rota**: em `/lojas/3`, ele vale `3`.
- `com_historico` é um **parâmetro de consulta** (*query*): em `/lojas/3?com_historico=true`, ele vale `True`. Como tem valor padrão, é opcional.

Os tipos também são validados aqui: `/lojas/abc` recebe 422, porque `abc` não é um inteiro.

---

## 4. Validação com Pydantic

### 4.1 O schema de entrada

O Pydantic é a biblioteca de validação que o FastAPI usa. Você descreve o formato esperado numa classe que herda de `BaseModel` (o **schema**), e o FastAPI confere cada requisição contra ela:

```python
from pydantic import BaseModel, Field


class Dia(BaseModel):
    """Entradas do modelo: os nomes e a ordem são os mesmos do treino."""
    loja: int = Field(ge=1, description="Código da loja")
    promocao: bool = Field(description="Há promoção no dia?")
    temperatura: float = Field(ge=-10, le=50, description="Temperatura média (°C)")
    dia_semana: int = Field(ge=0, le=6, description="0 = segunda, 6 = domingo")
    media_movel: float = Field(ge=0, description="Média de vendas dos 7 dias anteriores")


@app.post("/predict")
def predict(dia: Dia):
    ...
```

Como `dia` tem o tipo `Dia`, o FastAPI lê o corpo JSON, valida e entrega à função um objeto já conferido.

- O **tipo** de cada campo é obrigatório na validação: `"promocao": "sim"` não é um booleano válido.
- Todo campo sem valor padrão é **obrigatório**.
- `Field(ge=..., le=...)` define **limites** (`ge` = maior ou igual; `le` = menor ou igual; `gt` e `lt` são os estritos).
- O `description` aparece na página `/docs`.

Uma chamada com `"dia_semana": 7` nem chega ao modelo. A resposta é 422:

```json
{"detail": [{"type": "less_than_equal", "loc": ["body", "dia_semana"],
             "msg": "Input should be less than or equal to 6", "input": 7, "ctx": {"le": 6}}]}
```

O campo `loc` diz onde está o problema, e `msg` diz qual é. Se houver vários problemas, todos aparecem na lista.

> [!NOTE]
> A validação barra o **impossível** (um dia da semana 7, uma temperatura de 80 °C), não o **incomum**. Uma semana muito mais quente que o normal, com todos os valores dentro dos limites, passa. Perceber esse tipo de mudança é tarefa do monitoramento, não da API.

### 4.2 O schema de saída

A resposta também pode ter um schema. Declarado como tipo de retorno da função, ele é validado e aparece na documentação:

```python
class Previsao(BaseModel):
    vendas: int
    model_version: str


@app.post("/predict")
def predict(dia: Dia) -> Previsao:
    ...
    return Previsao(vendas=119, model_version="1")
```

Uma alternativa equivalente é declarar no decorador: `@app.post("/predict", response_model=Previsao)`.

Devolver a versão do modelo junto da previsão é uma boa prática de rastreabilidade: quem recebe a resposta sabe qual modelo a gerou. Pelo mesmo motivo, também é comum devolver o `run_id` do MLflow.

### 4.3 Nota sobre `def` e `async def`

As rotas podem ser declaradas com `def` ou com `async def`. Para servir modelos, use `def`. O `predict` do scikit-learn (e da maioria das bibliotecas de ML) é um cálculo que ocupa o processador e não sabe "esperar" de forma assíncrona. Com `def`, o FastAPI roda a função numa *thread* separada e continua atendendo as outras requisições. Com `async def`, um `predict` demorado travaria o servidor inteiro até terminar.

O `async def` faz sentido quando a rota passa a maior parte do tempo esperando outro serviço e usa bibliotecas assíncronas para isso (por exemplo, `httpx.AsyncClient`).

### 4.4 Pydantic e a signature do MLflow

O modelo logado com signature (veja o material de MLflow) também confere as entradas. As duas validações parecem redundantes, mas atuam em camadas diferentes e se complementam:

- **Pydantic (camada da API):** confere a requisição HTTP. Barra dados inválidos na porta de entrada, devolve um erro 422 claro para quem chamou e gera a documentação.
- **Signature do MLflow (camada do modelo):** viaja junto com o modelo. Garante que as colunas e os tipos que o modelo espera estejam documentados e sejam conferidos em qualquer lugar onde ele for carregado, com ou sem API.

Em resumo: o Pydantic protege a aplicação; a signature protege o modelo.

Na prática, o schema da API deve ter os mesmos nomes de coluna da signature. Um detalhe de tipos: o JSON entrega inteiros e booleanos, mas um modelo treinado com colunas `float64` tem uma signature que espera `double`. Converter o DataFrame antes do `predict` resolve:

```python
X = pd.DataFrame([dia.model_dump()]).astype("float64")
```

Sem essa conversão, o MLflow recusa a entrada com um `MlflowException` (*Failed to enforce schema*).

### 4.5 Nomes de coluna que não são nomes válidos em Python

Se o modelo foi treinado com colunas como `"Temperatura Média (°C)"`, esse nome não pode ser um atributo Python. A solução é usar um nome em `snake_case` no código e declarar o nome original como **alias**:

```python
from pydantic import BaseModel, ConfigDict, Field


class Entrada(BaseModel):
    # aceita tanto o alias quanto o nome do atributo no JSON
    model_config = ConfigDict(validate_by_name=True, validate_by_alias=True)

    temperatura_media: float = Field(alias="Temperatura Média (°C)")
    dia_semana: int = Field(alias="Dia da Semana")


@app.post("/predict")
def predict(entrada: Entrada):
    # by_alias=True gera as chaves com os nomes originais
    X = pd.DataFrame([entrada.model_dump(by_alias=True)])
    ...
```

O `model_dump(by_alias=True)` devolve `{"Temperatura Média (°C)": ..., "Dia da Semana": ...}`, e o DataFrame fica com exatamente os nomes que a signature espera.

---

## 5. Carregando o modelo uma vez: `lifespan`

Carregar um modelo do MLflow leva segundos (ele é baixado do servidor); uma previsão leva milissegundos. Carregar o modelo dentro da rota repetiria o download a cada requisição e deixaria cada resposta muito mais lenta.

O jeito certo é carregar **uma vez, quando a API sobe**, e guardar o modelo na memória. O FastAPI faz isso com o **`lifespan`**, uma função que roda na inicialização e no desligamento do servidor:

```python
from contextlib import asynccontextmanager


@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP: roda uma vez, antes de a API aceitar requisições
    app.state.modelo, app.state.versao = carregar_modelo()
    yield
    # SHUTDOWN: roda quando o servidor é desligado
    app.state.modelo = None


app = FastAPI(lifespan=lifespan)
```

O `yield` divide a função em duas partes: o que vem antes roda ao ligar; o que vem depois, ao desligar. Entre os dois, a API está atendendo.

O **`app.state`** é um lugar para guardar objetos que a aplicação inteira usa e que não mudam a cada requisição: o modelo, a versão, uma conexão com banco de dados, configurações. Num arquivo só, um dicionário no próprio módulo funciona da mesma forma; o `app.state` faz diferença quando as rotas ficam em outros arquivos (seção 8).

### 5.1 Carregando pelo alias

A API não deve conhecer números de versão, só o alias, como qualquer consumidor do Model Registry:

```python
import mlflow
from mlflow import MlflowClient

MODEL_NAME = "vendas-diarias"


def carregar_modelo():
    """Carrega a versão apontada pelo alias @champion e devolve (modelo, versão)."""
    versao = MlflowClient().get_model_version_by_alias(MODEL_NAME, "champion").version
    modelo = mlflow.pyfunc.load_model(f"models:/{MODEL_NAME}/{versao}")
    return modelo, versao
```

Primeiro o alias é traduzido para o número da versão, e depois essa versão é carregada. Assim a API sabe qual versão está servindo e pode devolvê-la nas respostas. Carregar direto com `mlflow.pyfunc.load_model("models:/vendas-diarias@champion")` também funciona, mas aí o número da versão fica desconhecido.

### 5.2 Onde a API encontra o MLflow

O endereço do servidor e as credenciais vêm de variáveis de ambiente, que o MLflow lê sozinho:

```bash
# .env  (nunca vai para o Git)
MLFLOW_TRACKING_URI=https://servidor-do-mlflow.exemplo.com
MLFLOW_TRACKING_USERNAME=seu_usuario
MLFLOW_TRACKING_PASSWORD=seu_token
```

O pacote `python-dotenv` carrega esse arquivo no início do `main.py`:

```python
from dotenv import load_dotenv

load_dotenv(override=True)  # override=True: o .env vence variáveis antigas do terminal
```

Com o servidor local da Aula 1, basta `MLFLOW_TRACKING_URI=http://127.0.0.1:5000`.

---

## 6. A API de vendas completa

Juntando as seções anteriores, a API inteira cabe num arquivo:

```python
# api/main.py
"""API de previsão de vendas diárias."""
from contextlib import asynccontextmanager

import mlflow
import pandas as pd
from dotenv import load_dotenv
from fastapi import FastAPI
from mlflow import MlflowClient
from pydantic import BaseModel, Field

load_dotenv(override=True)  # lê o .env (MLFLOW_TRACKING_URI e credenciais)

MODEL_NAME = "vendas-diarias"


class Dia(BaseModel):
    """Entradas do modelo: os nomes e a ordem são os mesmos do treino."""
    loja: int = Field(ge=1, description="Código da loja")
    promocao: bool = Field(description="Há promoção no dia?")
    temperatura: float = Field(ge=-10, le=50, description="Temperatura média (°C)")
    dia_semana: int = Field(ge=0, le=6, description="0 = segunda, 6 = domingo")
    media_movel: float = Field(ge=0, description="Média de vendas dos 7 dias anteriores")


class Previsao(BaseModel):
    vendas: int
    model_version: str


def carregar_modelo():
    """Carrega a versão apontada pelo alias @champion e devolve (modelo, versão)."""
    versao = MlflowClient().get_model_version_by_alias(MODEL_NAME, "champion").version
    modelo = mlflow.pyfunc.load_model(f"models:/{MODEL_NAME}/{versao}")
    return modelo, versao


@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP: roda uma vez, quando a API sobe
    app.state.modelo, app.state.versao = carregar_modelo()
    yield
    # SHUTDOWN: roda quando a API é desligada
    app.state.modelo = None


app = FastAPI(title="API de Vendas", version="1.0.0", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_NAME, "model_version": app.state.versao}


@app.post("/predict")
def predict(dia: Dia) -> Previsao:
    X = pd.DataFrame([dia.model_dump()]).astype("float64")
    vendas = float(app.state.modelo.predict(X)[0])
    # Regra de negócio: vendas não são negativas nem fracionadas
    return Previsao(vendas=max(0, round(vendas)), model_version=app.state.versao)
```

O caminho de uma requisição em `/predict`:

1. O FastAPI recebe o JSON e o Pydantic o valida contra `Dia`. Se falhar, a resposta é 422 e o modelo nem é chamado.
2. O objeto validado vira um DataFrame de uma linha, com os tipos que a signature espera.
3. O modelo, já na memória desde o `lifespan`, faz a previsão.
4. A regra de negócio ajusta o valor, e a resposta segue o schema `Previsao`.

Colocando no ar e testando:

```bash
uvicorn api.main:app --port 8000 --reload
```

```bash
curl -s localhost:8000/health
# {"status":"ok","model":"vendas-diarias","model_version":"1"}

curl -s -X POST localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"loja": 2, "promocao": true, "temperatura": 28.5, "dia_semana": 4, "media_movel": 112.3}'
# {"vendas":119,"model_version":"1"}
```

> [!IMPORTANT]
> Se o modelo não carregar (servidor do MLflow fora do ar, credenciais erradas, alias inexistente), o `lifespan` gera um erro e a API não sobe: o Uvicorn mostra `Application startup failed`. É um comportamento desejável: uma API que não consegue prever não deveria parecer saudável. A seção 7 mostra a alternativa.

---

## 7. Erros e códigos de status

Sem tratamento, qualquer erro no seu código vira um 500 genérico, sem explicação. A classe `HTTPException` permite responder com o código certo e uma mensagem útil. O módulo `status` do FastAPI tem os códigos com nomes legíveis:

```python
from fastapi import HTTPException, status

raise HTTPException(
    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
    detail="O modelo não está carregado.",
)
```

### 7.1 Duas estratégias quando o modelo não carrega

| Estratégia | Como funciona | Quando faz sentido |
|---|---|---|
| **Não subir** (seção 6) | O erro no `lifespan` interrompe a inicialização | Quando quem gerencia o serviço reinicia ou avisa sozinho ao ver que ele não subiu |
| **Subir e responder 503** | O `lifespan` captura o erro; o `/health` mostra o problema e o `/predict` responde 503 | Quando é útil a API estar no ar para diagnóstico, mesmo sem modelo |

A segunda estratégia fica assim:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.modelo, app.state.versao, app.state.erro = None, None, None
    try:
        app.state.modelo, app.state.versao = carregar_modelo()
    except Exception as exc:          # a API sobe mesmo assim
        app.state.erro = str(exc)
    yield


@app.get("/health")
def health():
    return {
        "status": "ok" if app.state.modelo is not None else "sem modelo",
        "model_version": app.state.versao,
        "erro_ao_iniciar": app.state.erro,
    }


@app.post("/predict")
def predict(dia: Dia) -> Previsao:
    if app.state.modelo is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "mensagem": "O modelo não está carregado.",
                "dica": "Confira o MLFLOW_TRACKING_URI e se existe o alias @champion.",
            },
        )
    ...
```

### 7.2 Documentando os erros

O FastAPI já documenta sozinho o 200 e o 422 (este último sempre que a rota recebe um schema). Os erros que você levanta com `HTTPException` precisam ser declarados no decorador para aparecer no `/docs`. Como a `HTTPException` coloca o conteúdo dentro da chave `detail`, o schema do erro segue esse formato:

```python
class DetalheErro(BaseModel):
    mensagem: str
    dica: str


class Erro(BaseModel):
    detail: DetalheErro


@app.post(
    "/predict",
    responses={503: {"model": Erro, "description": "Modelo não carregado"}},
)
def predict(dia: Dia) -> Previsao:
    ...
```

A resposta real do 503 fica assim:

```json
{"detail": {"mensagem": "O modelo não está carregado.",
            "dica": "Confira o MLFLOW_TRACKING_URI e se existe o alias @champion."}}
```

> [!NOTE]
> Se o Pydantic aprovou a entrada, mas a signature do MLflow a recusou, o problema não é de quem chamou: o schema da API e o modelo em uso deixaram de concordar (por exemplo, foi promovido um modelo treinado com outra feature). É um erro do servidor, que precisa ser corrigido no código ou no Registry.

---

## 8. Organizando a API em vários arquivos

Num arquivo só, uma API pequena fica legível. Quando ela cresce, o FastAPI permite separar as rotas em módulos. A estrutura abaixo segue o guia oficial *Bigger Applications* (<https://fastapi.tiangolo.com/pt/tutorial/bigger-applications/>):

```
api/
├── __init__.py
├── main.py          # cria o app, o lifespan e inclui as rotas
├── modelo.py        # carregar_modelo() e o nome do modelo
├── schemas.py       # Dia, Previsao, Erro
└── rotas/
    ├── __init__.py
    ├── saude.py     # GET /health
    └── previsao.py  # POST /predict
```

Duas peças tornam isso possível:

- **`APIRouter`:** funciona como uma "mini-aplicação", um conjunto de rotas num arquivo separado. No `main.py`, cada roteador é ligado ao app com `app.include_router(...)`.
- **`Request`:** o objeto que representa a requisição. Pelo atributo `request.app`, uma rota em outro arquivo acessa o `app.state` (e, portanto, o modelo) sem importar o `app` do `main.py`. Importar o `app` criaria uma importação circular, porque o `main.py` importa as rotas.

```python
# api/rotas/previsao.py
import pandas as pd
from fastapi import APIRouter, HTTPException, Request, status

from ..schemas import Dia, Erro, Previsao

router = APIRouter(tags=["previsão"])


@router.post(
    "/predict",
    responses={503: {"model": Erro, "description": "Modelo não carregado"}},
)
def predict(request: Request, dia: Dia) -> Previsao:
    estado = request.app.state
    if estado.modelo is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "mensagem": "O modelo não está carregado.",
                "dica": "Confira o MLFLOW_TRACKING_URI e se existe o alias @champion.",
            },
        )
    X = pd.DataFrame([dia.model_dump()]).astype("float64")
    vendas = float(estado.modelo.predict(X)[0])
    return Previsao(vendas=max(0, round(vendas)), model_version=estado.versao)
```

```python
# api/main.py
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI

from .modelo import carregar_modelo
from .rotas import previsao, saude

load_dotenv(override=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.modelo, app.state.versao, app.state.erro = None, None, None
    try:
        app.state.modelo, app.state.versao = carregar_modelo()
    except Exception as exc:
        app.state.erro = str(exc)
    yield


app = FastAPI(title="API de Vendas", version="1.0.0", lifespan=lifespan)
app.include_router(saude.router)
app.include_router(previsao.router)
```

O comando para subir não muda: `uvicorn api.main:app --port 8000`. O `tags=[...]` do roteador agrupa as rotas por seção na página `/docs`.

---

## 9. Testando a API

O FastAPI tem um **`TestClient`**, que chama a API dentro do próprio processo do Python, sem servidor e sem rede. Com o `pytest`, cada teste é uma função que faz uma chamada e confere a resposta.

O detalhe importante: os testes não devem depender do servidor do MLflow. Eles testam o **contrato da API** (rotas, validação, formato da resposta), não a qualidade do modelo. Para isso, trocamos o carregamento por um **modelo falso**:

```python
# tests/test_api.py
import numpy as np
import pytest
from fastapi.testclient import TestClient

import api.main as main

EXEMPLO = {"loja": 2, "promocao": True, "temperatura": 28.5, "dia_semana": 4, "media_movel": 112.3}


class ModeloFalso:
    """Responde sempre o mesmo valor: aqui testamos a API, não o modelo."""
    def predict(self, X):
        return np.full(len(X), 98.6)


@pytest.fixture
def client(monkeypatch):
    # troca carregar_modelo por uma função que devolve o modelo falso
    monkeypatch.setattr(main, "carregar_modelo", lambda: (ModeloFalso(), "teste"))
    with TestClient(main.app) as c:   # o "with" dispara o lifespan
        yield c


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["model_version"] == "teste"


def test_predict(client):
    r = client.post("/predict", json=EXEMPLO)
    assert r.status_code == 200
    assert r.json() == {"vendas": 99, "model_version": "teste"}   # 98,6 arredondado
```

- A **fixture** `client` prepara o terreno para cada teste: troca a função de carregamento (`monkeypatch.setattr`) e abre o `TestClient`.
- O `with TestClient(...)` executa o `lifespan`; sem o `with`, o modelo não seria "carregado".
- Entradas inválidas são testadas da mesma forma, conferindo o código de status da resposta.

Para o `pytest` encontrar o pacote `api`, um `pytest.ini` na raiz do repositório:

```ini
[pytest]
pythonpath = .
```

E para rodar:

```bash
pytest -q
```

O `TestClient` precisa do pacote `httpx2`, que já está nas dependências da disciplina.

Como não dependem de rede nem de credenciais, esses testes rodam em segundos e podem rodar automaticamente a cada `git push`.

---

## 10. Boas práticas

- Declare um schema Pydantic para a entrada e outro para a saída. O contrato fica explícito no código e na página `/docs`.
- Use limites (`Field(ge=..., le=...)`) para barrar valores impossíveis, e `description` para documentar cada campo.
- Mantenha os nomes do schema iguais aos da signature do modelo (com aliases, se preciso).
- Carregue o modelo uma única vez, no `lifespan`. Nunca dentro da rota.
- Carregue o modelo pelo alias (`@champion`), nunca por um número de versão fixo no código.
- Devolva a versão do modelo nas respostas e no `/health`.
- Tenha uma rota `/health`: é ela que ferramentas de monitoramento e testes automáticos consultam.
- Use `def` (e não `async def`) nas rotas que chamam o `predict`.
- Responda com os códigos de status certos (`HTTPException` + módulo `status`) e mensagens que ajudem a resolver o problema.
- Credenciais vêm de variáveis de ambiente (`.env` fora do Git). Nunca escritas no código.
- Teste a API com um modelo falso, sem depender do MLflow.
- Use `--reload` só no desenvolvimento.
