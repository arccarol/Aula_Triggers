CREATE DATABASE ex_triggers_07
GO
USE ex_triggers_07
GO
CREATE TABLE cliente (
codigo INT NOT NULL,
nome VARCHAR(70) NOT NULL
PRIMARY KEY(codigo)
)
GO
CREATE TABLE venda (
codigo_venda INT NOT NULL,
codigo_cliente INT NOT NULL,
codigo_produto INT NOT NULL,
valor_total DECIMAL(7,2) NOT NULL
PRIMARY KEY (codigo_venda)
FOREIGN KEY (codigo_cliente) REFERENCES cliente(codigo),
FOREIGN KEY (codigo_produto) REFERENCES produto(codigo_produto)
)
GO
CREATE TABLE pontos (
codigo_cliente INT NOT NULL,
total_pontos DECIMAL(4,1) NOT NULL
PRIMARY KEY (codigo_cliente)
FOREIGN KEY (codigo_cliente) REFERENCES cliente(codigo)
)
GO
CREATE TABLE produto (
codigo_produto INT NOT NULL,
nome VARCHAR(30) NOT NULL,
valor_produto DECIMAL(7,2) NOT NULL
PRIMARY KEY(codigo_produto)
)
 
INSERT INTO cliente VALUES
(3, 'Carol')
 
 
INSERT INTO venda VALUES
(4, 3, 2, 2020.99),
(2, 1, 1, 4000.00)
 
INSERT INTO produto VALUES
(2, 'Celular', 2000.99)
 
--- Para não prejudicar a tabela venda, nenhum produto pode ser deletado, mesmo que não
--venha mais a ser vendido
 
CREATE TRIGGER t_delprod ON produto
FOR DELETE
AS
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Não é possível excluir nenhum produto', 16, 1)
END
 
DELETE produto
WHERE codigo_produto = 1;
 
-- Para não prejudicar os relatórios e a contabilidade, a tabela venda não pode ser alterada.
 
CREATE TRIGGER t_alvend ON venda
FOR UPDATE
AS
BEGIN
	ROLLBACK TRANSACTION
	RAISERROR('Não é possível alterar nenhuma venda', 16, 1)
END
 
UPDATE venda
SET valor_total = 2100.99
WHERE codigo_venda = 1
 
-- Ao invés de alterar a tabela venda deve-se exibir uma tabela com o nome do último cliente que
--comprou e o valor da última compra
 
CREATE TRIGGER t_updtvenda ON venda
INSTEAD OF UPDATE
AS
BEGIN
      SELECT c.nome AS "Último Cliente", v.valor_total AS "Última Compra"
      FROM venda v
      JOIN cliente c ON v.codigo_cliente = c.codigo
      WHERE v.codigo_venda = (SELECT MAX(codigo_venda) FROM venda);
END
 
 
-- Após a inserção de cada linha na tabela venda, 10% do total deverá ser transformado em pontos.
 
CREATE TRIGGER t_insert_venda ON venda
AFTER INSERT
AS
BEGIN
    DECLARE @total_venda DECIMAL(7, 2);
    DECLARE @codigo_cliente INT;
	DECLARE @pontos DECIMAL(7, 2);
    SELECT @total_venda = valor_total, @codigo_cliente = codigo_cliente
    FROM INSERTED;
    SET @pontos = @total_venda * 0.1;
    INSERT INTO pontos (codigo_cliente, total_pontos)
    VALUES (@codigo_cliente, @pontos);
END;

-- Se o cliente ainda não estiver na tabela de pontos, deve ser inserido automaticamente após
--sua primeira compra

CREATE TRIGGER trgAfterInsertVenda
ON venda
AFTER INSERT
AS
BEGIN
    DECLARE @codigo_cliente INT;
   
    SELECT @codigo_cliente = i.codigo_cliente FROM inserted i;
    IF NOT EXISTS (SELECT 1 FROM pontos WHERE codigo_cliente = @codigo_cliente)
    BEGIN
        INSERT INTO pontos (codigo_cliente, total_pontos)
        VALUES (@codigo_cliente, 0.0);
    END
END;
GO


--- Se o cliente atingir 1 ponto, deve receber uma mensagem (PRINT SQL Server) dizendo que
--ganhou e remove esse 1 ponto da tabela de pontos

CREATE TRIGGER trgCheckPoints
ON pontos
AFTER UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE total_pontos >= 1)
    BEGIN
        PRINT 'Você ganhou um ponto.';
        DECLARE @codigo_cliente INT;

        SELECT @codigo_cliente = i.codigo_cliente FROM inserted i;

        UPDATE pontos
        SET total_pontos = total_pontos - 1
        WHERE codigo_cliente = @codigo_cliente;
    END
END;
GO

select * from pontos


CREATE TABLE produtos (
    codigo INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    valor_unitario DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (codigo)
);

INSERT INTO produtos (codigo, nome, descricao, valor_unitario) VALUES
(1, 'Televisor 32"', 'Televisor de 32 polegadas com alta definição', 1200.00),
(2, 'Microondas Basic', 'Microondas de 800W de potência', 300.00)

CREATE TABLE estoque (
    codigo_produto INT NOT NULL,
    quantidade_estoque INT NOT NULL,
    estoque_minimo INT NOT NULL,
    PRIMARY KEY (codigo_produto),
    FOREIGN KEY (codigo_produto) REFERENCES produtos(codigo)
);

INSERT INTO estoque (codigo_produto, quantidade_estoque, estoque_minimo) VALUES
(1, 50, 5),
(2, 30, 4);


CREATE TABLE vendas (
    nota_fiscal INT NOT NULL,
    codigo_produto INT NOT NULL,
    quantidade INT NOT NULL,
    PRIMARY KEY (nota_fiscal, codigo_produto),
    FOREIGN KEY (codigo_produto) REFERENCES produtos(codigo)
);


-- Fazer uma TRIGGER AFTER na tabela Venda que, uma vez feito um INSERT, verifique se a quan�dade
--está disponível em estoque.

CREATE TRIGGER trgAfterVenda
ON vendas
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @codigo_produto INT;
    DECLARE @quantidade INT;
    DECLARE @nota_fiscal INT;
    DECLARE @quantidade_estoque INT;
    DECLARE @estoque_minimo INT;

    SELECT @codigo_produto = codigo_produto, @quantidade = quantidade, @nota_fiscal = nota_fiscal
    FROM inserted;

    SELECT @quantidade_estoque = quantidade_estoque, @estoque_minimo = estoque_minimo
    FROM estoque
    WHERE codigo_produto = @codigo_produto;

    IF @quantidade > @quantidade_estoque
    BEGIN
 
        RAISERROR('Quantidade desejada não está disponível em estoque. Venda cancelada.', 16, 1);
        ROLLBACK TRANSACTION;
    END
    ELSE
    BEGIN

        UPDATE estoque
        SET quantidade_estoque = @quantidade_estoque - @quantidade
        WHERE codigo_produto = @codigo_produto;

        IF (@quantidade_estoque - @quantidade) < @estoque_minimo
        BEGIN
            PRINT 'Atenção: Estoque abaixo do mínimo!';
        END
    END
END;
GO

INSERT INTO vendas (nota_fiscal, codigo_produto, quantidade) VALUES
(1002, 1, 46)

SELECT * from estoque



CREATE FUNCTION GetDetalhesVenda (@notaFiscal INT)
RETURNS @Detalhes TABLE
(
    Nota_Fiscal INT,
    Codigo_Produto INT,
    Nome_Produto VARCHAR(100),
    Descricao_Produto TEXT,
    Valor_Unitario DECIMAL(10, 2),
    Quantidade INT,
    Valor_Total DECIMAL(10, 2)
)
AS
BEGIN

    INSERT INTO @Detalhes
    SELECT
        v.nota_fiscal,
        v.codigo_produto,
        p.nome,
        p.descricao,
        p.valor_unitario,
        v.quantidade,
        p.valor_unitario * v.quantidade AS Valor_Total
    FROM
        vendas v
    INNER JOIN
        produtos p ON v.codigo_produto = p.codigo
    WHERE
        v.nota_fiscal = @notaFiscal;
    RETURN;
END;
GO


SELECT *
FROM dbo.GetDetalhesVenda(1002);
