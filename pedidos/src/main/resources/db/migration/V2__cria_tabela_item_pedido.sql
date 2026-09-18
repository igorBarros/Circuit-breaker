CREATE TABLE item_do_pedido (
  id        BIGSERIAL    NOT NULL,
  descricao VARCHAR(255) DEFAULT NULL,
  quantidade INTEGER     NOT NULL,
  pedido_id BIGINT       NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (pedido_id) REFERENCES pedidos(id)
);