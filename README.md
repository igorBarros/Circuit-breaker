# AluraFood - Circuit Breaker

Projeto de estudos baseado no curso da Alura sobre resiliência em arquiteturas de microsserviços, aplicando o padrão **Circuit Breaker** com Resilience4j em um ecossistema de microsserviços Spring Boot com service discovery e API Gateway.

## Arquitetura

O projeto é composto por 4 microsserviços independentes (cada um com seu próprio `pom.xml` e ciclo de vida):

| Serviço | Porta | Descrição |
|---|---|---|
| **server** | `8081` | Servidor de descoberta (Eureka Server) |
| **gateway** | `8082` | API Gateway (Spring Cloud Gateway) que roteia as requisições para os microsserviços |
| **pedidos** | `8080` | Microsserviço responsável pelo ciclo de vida dos pedidos |
| **pagamentos** | `9000` | Microsserviço responsável pelos pagamentos, com integração ao serviço de pedidos |

### Fluxo de comunicação

```
Cliente → Gateway (8082) → Pedidos (8080) / Pagamentos (9000)
                                                    │
                                        Feign Client (PedidoClient)
                                                    ▼
                                    Pedidos (via Eureka Service Discovery)
```

- Todos os serviços se registram no **Eureka Server** (`server`).
- O **gateway** expõe rotas públicas:
  - `/pedidos/**` → encaminha para o serviço `pedidos`
  - `/pagamentos/**` → encaminha para o serviço `pagamentos`
- O serviço **pagamentos** consome o serviço **pedidos** via **OpenFeign** (`PedidoClient`), usando o Eureka para resolver o endereço da instância.

## Circuit Breaker (Resilience4j)

O ponto central do projeto está no serviço `pagamentos`, no endpoint de confirmação de pagamento:

- `PATCH /pagamentos/{id}/confirmar` chama `PagamentoService.confirmarPagamento`, que atualiza o status do pagamento localmente e então notifica o serviço `pedidos` (via Feign) de que o pedido foi pago.
- Esse endpoint está anotado com `@CircuitBreaker(name = "atualizaPedido", fallbackMethod = "pagamentoAutorizadoSemAutorizacao")`.
- Caso o serviço `pedidos` esteja indisponível ou lento, o circuito abre e o método de **fallback** é acionado, marcando o pagamento com o status `CONFIRMADO_SEM_INTEGRACAO` em vez de propagar o erro para o cliente.

Configuração do circuito (`pagamentos/src/main/resources/application.properties`):

```properties
resilience4j.circuitbreaker.instances.atualizaPedido.slidingWindowSize=3
resilience4j.circuitbreaker.instances.atualizaPedido.minimumNumberOfCalls=2
resilience4j.circuitbreaker.instances.atualizaPedido.waitDurationInOpenState=50s
```

## Tecnologias utilizadas

- **Java 17**
- **Spring Boot** (3.4.5 nos serviços de negócio / 4.0.6 em gateway e server)
- **Spring Cloud** (Gateway, Eureka Client/Server, OpenFeign)
- **Resilience4j** (`resilience4j-spring-boot3`) — Circuit Breaker
- **Spring Data JPA** + **PostgreSQL**
- **Flyway** — versionamento e migração de schema do banco
- **ModelMapper** — conversão entre entidades e DTOs
- **Bean Validation** (`spring-boot-starter-validation`)
- **Lombok**
- **Maven** (via Maven Wrapper)

## Estrutura de cada microsserviço de negócio

### pedidos
- `PedidoController` — CRUD de pedidos, atualização de status e endpoint `PUT /pedidos/{id}/pago` (chamado pelo serviço de pagamentos).
- `PedidoService`, `PedidoRepository`, entidades `Pedido`, `ItemDoPedido`, `Status`.
- Migrations Flyway: criação das tabelas `pedidos` e `item_pedido`.

### pagamentos
- `PagamentoController` — CRUD de pagamentos e endpoint de confirmação protegido por Circuit Breaker.
- `PagamentoService` — regras de negócio, incluindo a chamada ao serviço de pedidos.
- `PedidoClient` — cliente Feign para comunicação com o microsserviço `pedidos`.
- Migration Flyway: criação da tabela `pagamentos`.

## Como executar

Pré-requisitos: Java 17, Maven (ou usar o `mvnw` incluso em cada módulo) e um banco PostgreSQL configurado conforme `application.properties` de cada serviço.

1. Suba o **Eureka Server**:
   ```bash
   cd server && ./mvnw spring-boot:run
   ```
2. Suba o **Gateway**:
   ```bash
   cd gateway && ./mvnw spring-boot:run
   ```
3. Suba o serviço **pedidos**:
   ```bash
   cd pedidos && ./mvnw spring-boot:run
   ```
4. Suba o serviço **pagamentos**:
   ```bash
   cd pagamentos && ./mvnw spring-boot:run
   ```

Após todos os serviços estarem registrados no Eureka (`http://localhost:8081`), as requisições podem ser feitas através do gateway em `http://localhost:8082`.

## Testando o Circuit Breaker

Para observar o comportamento do circuito:
1. Crie um pedido e um pagamento associado a ele.
2. Derrube o serviço `pedidos`.
3. Chame `PATCH /pagamentos/{id}/confirmar` repetidas vezes.
4. Após o número mínimo de chamadas falhas (`minimumNumberOfCalls=2`) dentro da janela (`slidingWindowSize=3`), o circuito abre e as próximas chamadas passam a acionar diretamente o fallback, marcando o pagamento como `CONFIRMADO_SEM_INTEGRACAO` sem tentar contatar o serviço `pedidos`.
