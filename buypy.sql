/*
    DDL for the BuyPy Online Store.

    (c) Joao Galamba, 2022
 */
SET SQL_SAFE_UPDATES = 0; -- Assim não precisamos de password sempre ...
DELIMITER //

DROP DATABASE IF EXISTS BuyPy
//
CREATE DATABASE BuyPy
//

USE BuyPy
//

DROP TABLE IF EXISTS `Client`
//
CREATE TABLE `Client`(
    id              INT PRIMARY KEY AUTO_INCREMENT,
    firstname       VARCHAR(250) NOT NULL,
    surname         VARCHAR(250) NOT NULL,
    email           VARCHAR(50) NOT NULL UNIQUE,
    `password`      CHAR(64) NOT NULL COMMENT 'Holds the hashed password',
    address         VARCHAR(100) NOT NULL,
    zip_code        SMALLINT UNSIGNED NOT NULL,
    city            VARCHAR(30) NOT NULL,
    country         VARCHAR(30) NOT NULL DEFAULT 'Portugal',
    phone_number    VARCHAR(15) NOT NULL CHECK(phone_number RLIKE '^[0-9]{6,}$'),
    last_login      TIMESTAMP NOT NULL DEFAULT (NOW()),
    birthdate       DATE NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,

    CONSTRAINT ClientEmailChk CHECK(email RLIKE "[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
    -- CONSTRAINT EmailChk CHECK(email RLIKE "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"),

    -- Exemplos de CONSTRAINTs para a password mas que não podem aqui ficar por causa
    -- do hashing da pwd que é feito no trigger
    
    -- CONSTRAINT PasswdChk CHECK(`password` RLIKE "(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!$#?%]).{6,}")
    -- CONSTRAINT PasswdChk CHECK(
    --         LENGTH(`password`) >= 6
    --     AND `password` RLIKE '[a-z]'
    --     AND `password` RLIKE '[A-Z]'
    --     AND `password` RLIKE '[0-9]'
    --     AND `password` RLIKE '[!$#?%]'
    -- )
)//


DROP TRIGGER IF EXISTS BeforeNewClient
//
CREATE TRIGGER BeforeNewClient BEFORE INSERT ON `Client`
FOR EACH ROW
BEGIN
    CALL ValidateClient(NEW.phone_number, NEW.country, NEW.`password`);
END//

DROP TRIGGER IF EXISTS BeforeUpdatingClient
//
CREATE TRIGGER BeforeUpdatingClient BEFORE UPDATE ON `Client`
FOR EACH ROW
BEGIN
    CALL ValidateClient(NEW.phone_number, NEW.country, NEW.`password`);
END//

DROP PROCEDURE IF EXISTS ValidateClient
//
CREATE PROCEDURE ValidateClient(
    IN phone_number   VARCHAR(15),
    IN country        VARCHAR(30),
    INOUT `password`  CHAR(64)
)
BEGIN
    DECLARE INVALID_PHONE_NUMBER CONDITION FOR SQLSTATE '45000';
    DECLARE INVALID_PASSWORD CONDITION FOR SQLSTATE '45001';
    
    IF country = 'Portugal' AND LEFT(phone_number, 3) <> '351' THEN
        SIGNAL INVALID_PHONE_NUMBER
            SET MESSAGE_TEXT = 'Invalid phone number for Portugal';
    END IF;

    -- We have to this, and not with CHECK CONSTRAINT because
    -- by that time, the password is already hashed (see below)
    -- The password can only be hashed here, in this trigger.
    -- IF `password` NOT RLIKE "(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!$#?%]).{6,}" THEN
    --    SIGNAL INVALID_PASSWORD
    --        SET MESSAGE_TEXT = 'Invalid password';
    -- END IF;

    SET `password` := SHA2(`password`, 256);

END//

-- SET @password = 'abc'
-- //
-- CALL ValidateClient('351232323', 'Portugal', @password)
-- //
-- SELECT @password
-- //

DROP TABLE IF EXISTS `Order`
//
CREATE TABLE `Order`(
    id              INT PRIMARY KEY AUTO_INCREMENT,
    date_time       DATETIME NOT NULL DEFAULT (NOW()),
    delivery_method ENUM('regular', 'urgent') DEFAULT 'regular',
    status          ENUM('open', 'processing', 'pending', 'closed', 'cancelled')
                        DEFAULT 'open',
    payment_card_number         BIGINT NOT NULL,
    payment_card_name           VARCHAR(20) NOT NULL,
    payment_card_expiration     DATE NOT NULL,
    client_id       INT NOT NULL,

    -- Isto não é possível
    -- CONSTRAINT ExpirationDate CHECK(payment_card_expiration >= CURRENT_DATE),

    FOREIGN KEY ClientFK (client_id) REFERENCES `Client`(id)
)//


DROP TRIGGER IF EXISTS ValidateOrder
//
CREATE TRIGGER ValidateOrder BEFORE INSERT ON `Order`
FOR EACH ROW 
BEGIN
    DECLARE INVALID_EXPIRATION_DATE CONDITION FOR SQLSTATE '45002';
    IF NEW.payment_card_expiration < CURDATE() THEN
        SIGNAL INVALID_EXPIRATION_DATE
            SET MESSAGE_TEXT = 'Invalid card expiration date';
    END IF;
END//


DROP TABLE IF EXISTS Product
//
CREATE TABLE Product(
    id              CHAR(10) PRIMARY KEY,
    quantity        INT UNSIGNED NOT NULL,
    price           DECIMAL(10,2) NOT NULL CHECK(price >= 0),
    vat             DECIMAL(4,2) CHECK(vat BETWEEN 0 AND 100),
    score           TINYINT CHECK(score BETWEEN 1 AND 5),
    product_image   VARCHAR(1000) COMMENT 'URL for the image',
    active          BOOL NOT NULL DEFAULT TRUE,
    reason          VARCHAR(500) COMMENT 'Why the account is active/inactive'
)//

DROP TABLE IF EXISTS Ordered_Item
//
CREATE TABLE Ordered_Item(
    id              INT PRIMARY KEY AUTO_INCREMENT,
    quantity        INT UNSIGNED NOT NULL,
    price           DECIMAL(10,2) NOT NULL CHECK(price >= 0),
    vat             DECIMAL(4,2) CHECK(vat BETWEEN 0 AND 100),
    vat_amount		DECIMAL(10,2) NOT NULL CHECK(vat_amount > 0),
    order_id		INT,
    product_id		CHAR(10),
    
    FOREIGN KEY OrderID (order_id) REFERENCES `Order`(id),
    FOREIGN KEY ProductID (product_id) REFERENCES `Product`(id)
)//


/*
CREATE TRIGGER BeforeNewOrderedItem BEFORE INSERT ON `Ordered_Item`
FOR EACH ROW 
BEGIN
    DECLARE prod_price      DECIMAL(10,2);
    DECLARE prod_quantity   INT UNSIGNED;
    DECLARE vat             DECIMAL(4,2);

    SELECT  price, quantity, vat 
    INTO    prod_price, prod_quantity, vat
    FROM    Product
    WHERE   id = NEW.product_id;

    -- NEW.vat_amount = ...;
END//
*/

DROP TABLE IF EXISTS Book
//
CREATE TABLE Book(
    product_id          CHAR(10) PRIMARY KEY,
    isbn13              CHAR(20) NOT NULL UNIQUE,
    title               VARCHAR(50) NOT NULL,
    genre               VARCHAR(50) NOT NULL,
    publisher           VARCHAR(100) NOT NULL,
    publication_date    DATE NOT NULL,

    FOREIGN KEY ProductFK (product_id) REFERENCES Product(id)
        ON UPDATE CASCADE ON DELETE CASCADE,

    CONSTRAINT ISBN13Chk CHECK(isbn13 RLIKE '^[0-9\-]+$')
)//

DROP TRIGGER IF EXISTS ValidateBook
//
CREATE TRIGGER ValidateBook BEFORE INSERT ON Book
FOR EACH ROW
BEGIN
    DECLARE INVALID_ISBN13 CONDITION FOR SQLSTATE '45023';
    IF NOT ValidISBN13(NEW.isbn13) THEN
        SIGNAL INVALID_ISBN13 
            SET MESSAGE_TEXT = 'Invalid ISBN-13';
    END IF;
END//

/*
 * See https://en.wikipedia.org/wiki/ISBN#ISBN-13_check_digit_calculation
 */
DROP FUNCTION IF EXISTS ValidISBN13
//
CREATE FUNCTION ValidISBN13(isbn13 VARCHAR(20))
RETURNS BOOL
DETERMINISTIC
BEGIN
    DECLARE i TINYINT UNSIGNED DEFAULT 1;
    DECLARE s SMALLINT UNSIGNED DEFAULT 0;

    SET isbn13 = REPLACE(isbn13, '-', '');
    -- SET isbn13 = REPLACE(isbn13, ' ', '');
    -- SET isbn13 = REPLACE(isbn13, '_', '');

    IF isbn13 NOT RLIKE '^[0-9]{13}$' THEN
        RETURN FALSE;
    END IF;

    WHILE i < 14 DO
        SET s = s + SUBSTRING(isbn13, i, 1) * IF(i % 2 = 1, 1, 3);
        SET i = i + 1;
    END WHILE;

    RETURN s % 10 = 0;
END//

/*
 * O NIF tem 9 dígitos, sendo o último o digito de controlo. Para ser calculado o 
 * digito de controlo:
 * 
 * Multiplique: 
 *     o 8.º dígito por 2, 
 *     o 7.º dígito por 3, 
 *     o 6.º dígito por 4, 
 *     o 5.º dígito por 5, 
 *     o 4.º dígito por 6, 
 *     o 3.º dígito por 7, 
 *     o 2.º dígito por 8 e 
 *     o 1.º dígito por 9;
 * 
 * Some os resultados;
 * 
 * Calcule o resto da divisão do número por 11;
 * 
 * Se o resto for 0 (zero) ou 1 (um) o dígito de controlo será 0 (zero);
 * Se for outro qualquer algarismo X, o dígito de controlo será o resultado 
 * da subtracção 11 - X.
 */

DROP FUNCTION IF EXISTS ValidNIF
//
CREATE FUNCTION ValidNIF(NIF CHAR(9))
RETURNS BOOL
DETERMINISTIC
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE multiplicador INT DEFAULT 9;
    DECLARE Soma INT DEFAULT 0;
    DECLARE Resto INT DEFAULT 0;
    DECLARE DigControlo INT DEFAULT 0;

    IF NIF NOT RLIKE '^[0-9]{9}$' THEN
        RETURN FALSE;
    END IF;

    WHILE i < LENGTH(NIF) DO 
        SET Soma = Soma + SUBSTRING(NIF, i, 1) * multiplicador;
        SET multiplicador = multiplicador - 1;
        SET i = i + 1;
    END WHILE;
    
    SET Resto = Soma % 11;
    SET DigControlo = SUBSTRING(NIF, 9, 1);
    
    IF Resto IN (0, 1) THEN
        RETURN DigControlo = 0;
    END IF;
    RETURN DigControlo = 11 - Resto;
END//

/*********************************
***   		  Author           ***
**********************************/

DROP TABLE IF EXISTS `Author`
//
CREATE TABLE `Author`(
    id              INT PRIMARY KEY AUTO_INCREMENT,
    authname  		VARCHAR(250) NOT NULL,
    fullname		VARCHAR(250) NOT NULL,
    birthdate		DATE NOT NULL
)//

/*********************************
***   		BookAuthor         ***
**********************************/
DROP TABLE IF EXISTS `BookAuthor`
//
CREATE TABLE `BookAuthor`(
    id              INT PRIMARY KEY AUTO_INCREMENT,
    product_id      CHAR(10),
    author_id		INT,
	
    FOREIGN KEY ProductFK (product_id) REFERENCES `Book`(product_id),
    FOREIGN KEY AuthorFK (author_id) REFERENCES `Author`(id)
)//


/*********************************
***   		Electronic         ***
**********************************/
DROP TABLE IF EXISTS Electronic
//
CREATE TABLE Electronic(
    product_id          CHAR(10) PRIMARY KEY,
    serial_num          INT NOT NULL UNIQUE,
    brand               VARCHAR(50) NOT NULL,
    model               VARCHAR(50) NOT NULL,
    spec_tec            VARCHAR(100) NOT NULL,
    etype			    VARCHAR(50) NOT NULL,

    FOREIGN KEY ProductFK (product_id) REFERENCES Product(id)
)//

DROP TABLE IF EXISTS `Operator`
//
CREATE TABLE `Operator`(
    id              INT PRIMARY KEY AUTO_INCREMENT,
    firstname       VARCHAR(250) NOT NULL,
    surname         VARCHAR(250) NOT NULL,
    email           VARCHAR(50) NOT NULL UNIQUE,
    `password`      CHAR(64) NOT NULL COMMENT 'Holds the hashed password',

    CONSTRAINT OperatorEmailChk CHECK(email RLIKE "[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
)//

DROP TRIGGER IF EXISTS BeforeNewOperator
//
CREATE TRIGGER BeforeNewOperator BEFORE INSERT ON `Operator`
FOR EACH ROW
BEGIN
    CALL ValidateOperator(NEW.`password`);
END//

DROP TRIGGER IF EXISTS BeforeUpdatingOperator
//
CREATE TRIGGER BeforeUpdatingOperator BEFORE UPDATE ON `Operator`
FOR EACH ROW
BEGIN
    CALL ValidateOperator(NEW.`password`);
END//

DROP PROCEDURE IF EXISTS ValidateOperator
//
CREATE PROCEDURE ValidateOperator(
    INOUT `password`  CHAR(64)
)
BEGIN
    DECLARE INVALID_PASSWORD CONDITION FOR SQLSTATE '45001';

    -- We have to this, and not with CHECK CONSTRAINT because
    -- by that time, the password is already hashed (see below)
    -- The password can only be hashed here, in this trigger.
    IF `password` NOT RLIKE "(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])(?=.*[!$#?%]).{6,}" THEN
        SIGNAL INVALID_PASSWORD
            SET MESSAGE_TEXT = 'Invalid password';
    END IF;

    SET `password` := SHA2(`password`, 256);
END//

DROP PROCEDURE IF EXISTS AuthenticateOperator
//
CREATE PROCEDURE AuthenticateOperator(
    IN operator_email       VARCHAR(50),
    IN operator_passwd      CHAR(64)
)
BEGIN
    SELECT firstname, surname
    FROM `Operator`
    WHERE email = operator_email
    AND  `password` = operator_passwd;
END//

-- CALL AuthenticateOperator('pedro@mail.com', SHA2('123abC!', 256))
-- //

DROP PROCEDURE IF EXISTS ProdutoPorTipo
//
CREATE PROCEDURE `ProdutoPorTipo`(
	IN product_type	VARCHAR(50)
)
BEGIN
	IF(STRCMP(product_type,"'electronic'")=0) THEN
		SELECT id,price,score,reason,`active`,product_image FROM `Product` AS p
		JOIN `Electronic` AS e
		ON	p.id = e.product_id;
	ELSEIF(STRCMP(product_type,"'book'")=0) THEN
		SELECT id,price,score,reason,`active`,product_image FROM `Product` AS p
        JOIN `Book` AS b
        ON	p.id = b.product_id;
	ELSE
		SELECT id,price,score,reason,`active`,product_image FROM `Product`;
	END IF;
	
END//


DROP PROCEDURE IF EXISTS EncomendasDiarias
//
CREATE PROCEDURE `EncomendasDiarias`(
	IN ddata DATE
)
BEGIN
	SELECT * FROM `order` WHERE DATE(date_time)=ddata;
END//

DROP PROCEDURE IF EXISTS EncomendasAnuais
//
CREATE PROCEDURE `EncomendasAnuais`(
	IN id_cliente INT,
    IN ano INT
)
BEGIN
	SELECT * FROM `order` WHERE YEAR(date_time)=ano OR client_id=id_cliente;
END//


DROP PROCEDURE IF EXISTS CriarEncomenda
//
CREATE PROCEDURE `CriarEncomenda`(
	IN id_cliente INT,
    IN metodo enum('regular','urgent'),
    IN nr_cartao BIGINT,
    IN nome_cartao VARCHAR(20),
    IN exp_cartao DATE
)
BEGIN
	INSERT INTO `Order` 
		(client_id, delivery_method, payment_card_number, payment_card_name, payment_card_expiration)
	VALUES
		(id_cliente, metodo, nr_cartao, nome_cartao, exp_cartao);
END//


DROP PROCEDURE IF EXISTS CalcularTotal
//
CREATE PROCEDURE `CalcularTotal`(
	IN encomenda_id INT
)
BEGIN
	SELECT SUM(price) FROM `Ordered_item` WHERE `order_id`=encomenda_id;
END//

DROP PROCEDURE IF EXISTS AdicionarProduto
//
CREATE PROCEDURE `AdicionarProduto`(
	IN orderId INT,
    IN productId CHAR(10),
    IN quantidade INT UNSIGNED
)
BEGIN
	-- SELECT price, vat INTO @p, @v FROM `Product` WHERE id=productId;
    INSERT INTO `Ordered_item` (quantity, price, vat, vat_amount, order_id, product_id)
    SELECT `quantidade`, price, vat, vat/100*price, `orderId`, `productId`
    FROM `Product` WHERE id=productId;
END//


DROP PROCEDURE IF EXISTS CriarLivro
//
CREATE PROCEDURE `CriarLivro`(
	IN prodID CHAR(10),
    IN isbn13 CHAR(20),
    IN title VARCHAR(50),
    IN genre VARCHAR(50),
    IN publisher VARCHAR(100),
    IN publication_date DATE
)
BEGIN
	INSERT INTO `Book`
    VALUES (prodID,isbn13,title,genre,publisher,publication_date);
END//


DROP PROCEDURE IF EXISTS CriarConsumivelElec
//
CREATE PROCEDURE `CriarConsumivelElec`(
	IN prodID CHAR(10),
    IN serial_num INT,
    IN brand VARCHAR(50),
    IN model VARCHAR(50),
    IN spec_tec VARCHAR(100),
    IN etype VARCHAR(50)
)
BEGIN
	INSERT INTO `Electronic`
    VALUES (prodID, serial_num, brand, model, spec_tec, etype);
END//



/*
 * DATABASE USERS AND ACCOUNTS
 */

DROP USER IF EXISTS 'web_client'@'10.10.10.%'
//
CREATE USER 'web_client'@'10.10.10.%' IDENTIFIED BY 'MKlio182$'
//

DROP USER IF EXISTS 'operator'@'localhost'
//  
CREATE USER 'operator'@'localhost' IDENTIFIED BY 'abc'
//

DROP USER IF EXISTS 'operator'@'%'
//
CREATE USER 'operator'@'%' IDENTIFIED BY 'abc'
//

DROP USER IF EXISTS 'cliente'@'%'
//
CREATE USER 'cliente'@'%' IDENTIFIED BY '123'
//

DROP USER IF EXISTS 'cliente'@'localhost'
//
CREATE USER 'cliente'@'localhost' IDENTIFIED BY '123'
//

GRANT ALL PRIVILEGES ON * . * TO 'operator'@'localhost';
GRANT ALL PRIVILEGES ON * . * TO 'operator'@'%';

//
-- GRANT ALL PRIVILEGES ON buypy.* TO 'operator'@'localhost' WITH GRANT OPTION
//
-- GRANT ALL PRIVILEGES ON buypy.* TO 'operator'@'%' WITH GRANT OPTION
//

/*
    FRAGMENTOS DE CÓDIGO EXEMPLIFICATIVOS

    -- delivery_method VARCHAR(10) DEFAULT 'regular' 
    --                 CHECK(delivery_method IN ('regular', 'urgent')),
-- SET @pwd := 'aBcde6'
-- //
-- SELECT     LENGTH(@pwd) >= 6
-- 	   AND @pwd RLIKE BINARY '[a-z]'
--        AND @pwd RLIKE BINARY '[A-Z]' 
--        AND @pwd RLIKE BINARY '[0-9]'
-- //

*/

/*
CREATE PROCEDURE ValidateISBN13(IN isbn13 VARCHAR(20))
BEGIN
    DECLARE INVALID_ISBN13 CONDITION FOR SQLSTATE '45023';
    DECLARE i TINYINT UNSIGNED DEFAULT 1;
    DECLARE s SMALLINT UNSIGNED DEFAULT 0;

    -- See https://en.wikipedia.org/wiki/ISBN#ISBN-13_check_digit_calculation
    SET isbn13 = REPLACE(isbn13, '-', '');
    -- SET isbn13 = REPLACE(isbn13, ' ', '');
    -- SET isbn13 = REPLACE(isbn13, '_', '');

    IF isbn13 NOT RLIKE '^[0-9]{13}$' THEN
        SIGNAL INVALID_ISBN13 
           SET MESSAGE_TEXT = 'Invalid ISBN-13';
    END IF;

    WHILE i < 14 DO
        SET s = s + SUBSTRING(isbn13, i, 1) * IF(i % 2 = 1, 1, 3);
        SET i = i + 1;
    END WHILE;

    IF s % 10 <> 0 THEN
        SIGNAL INVALID_ISBN13 
           SET MESSAGE_TEXT = 'Invalid ISBN-13';
    END IF; 
END//
*/