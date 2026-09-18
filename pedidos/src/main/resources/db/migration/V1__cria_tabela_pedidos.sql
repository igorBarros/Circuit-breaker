CREATE TABLE pedidos (
  id        BIGSERIAL    NOT NULL,
  data_hora TIMESTAMP    NOT NULL,
  status    VARCHAR(255) NOT NULL,
  PRIMARY KEY (id)
);