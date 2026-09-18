package br.com.br.alurafood.pagamentos.repository;

import br.com.br.alurafood.pagamentos.model.Pagamento;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PagamentoRepository extends JpaRepository<Pagamento, Long> {

}
