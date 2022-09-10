/*
    DML for the BuyPy Online Store.

    (c)  Duarte Ferreira & Milton Cruz, 10/09/2022
 */

USE BuyPy;

DELETE FROM `Electronic`;
DELETE FROM `Book`;
DELETE FROM `Order`;
DELETE FROM `Client`;
DELETE FROM `Product`;
DELETE FROM `Operator`;
DELETE FROM `Electronic`;
DELETE FROM `Book`;

INSERT INTO `Client` 
    (firstname, surname, email, `password`,
        address, zip_code, city, country,
        phone_number, birthdate)
VALUES
    ('Alberto', 'Antunes', 'alb@mail.com', '123abC!',
        'Rua do Almada, n. 23', 9877, 'Lisboa', 'Portugal',
        '351213789123', '1981-05-23'),
        
    ('Arnaldo', 'Avelar', 'arnaldo@coldmail.com', '456deF!',
        'Av. América, n. 23', 2877, 'Porto', 'Portugal',
        '351213789123', '1981-05-23')
;

INSERT INTO Product
    (id, quantity, price, vat, score, product_image)
VALUES
    ('ELECAP9817', 20, 800, 23, 5, 'file:://mnt/imgs/products/elec/ipad_xii.jpg'),
    ('BOK129922A', 50, 8, 6, 3, 'file:://mnt/imgs/products/book/prog_c++.jpg')
;

INSERT INTO Book 
    (product_id, isbn13, title, genre, publisher, publication_date)
VALUES
    ('BOK129922A', '978-0-32-1563842', 'The C++ Programming Language 4th Edition', 
    'Programming', 'Addison-Wesley', '2013-06-05')
;

INSERT INTO Electronic
    (product_id, serial_num, brand, model, spec_tec, etype)
VALUES
    ('ELECAP9817', '123456', 'Apple', 
    'iPad XII', 'RTX3090', 'tablet')
;

/*DELETE FROM Book;*/

INSERT INTO `Order`
    (payment_card_number, payment_card_name, payment_card_expiration, client_id)
VALUES
    (121, 'DR. ALBERTO ANTUNES', '2023-05-23', (SELECT id FROM `Client` WHERE firstname = 'alberto' LIMIT 1))
;

/*
 * Create initial OPERATOR accounts.
 */

INSERT INTO `Operator` 
    (firstname, surname, email, `password`)
VALUES
    ('Pedro', 'Pereira', 'pedro@mail.com', '123abC!'),
    ('Paulo', 'Pacheco', 'paulo@coldmail.com', '456deF!')
;

-- SELECT * FROM `Operator`;


/*
SELECT * FROM `Client`;
SELECT * FROM `Order`;

SELECT SHA2('123abC', 256), LENGTH(SHA2('123abC', 256));

SELECT LEFT('919234108', 3);
*/

/*
    Clientes inválidos
INSERT INTO `Client` 
    (firstname, surname, email, `password`)
VALUES
    ('armando', 'almeida', 'arm@xpto.com', '123abC')
;
*/
