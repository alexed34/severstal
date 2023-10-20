--Postgresql


CREATE TABLE client (
	client_id serial4 NOT NULL,
	"name" varchar(255) NOT NULL,
	contact_person varchar(255) NULL,
	email varchar(255) NULL,
	phone varchar(20) NULL,
	address text NULL,
	CONSTRAINT client_pkey PRIMARY KEY (client_id)
);


-- severstal.manager definition

-- Drop table

-- DROP TABLE manager;

CREATE TABLE manager (
	manager_id serial4 NOT NULL,
	"name" varchar(255) NOT NULL,
	email varchar(255) NULL,
	phone varchar(20) NULL,
	CONSTRAINT manager_pkey PRIMARY KEY (manager_id)
);


-- severstal.orderaudit definition

-- Drop table

-- DROP TABLE orderaudit;

CREATE TABLE orderaudit (
	audit_id serial4 NOT NULL,
	order_id int4 NULL,
	attribute_name varchar(255) NULL,
	old_value text NULL,
	new_value text NULL,
	change_timestamp timestamptz NULL,
	manager_id name NULL COLLATE "C",
	CONSTRAINT orderaudit_pkey PRIMARY KEY (audit_id)
);


-- severstal.product definition

-- Drop table

-- DROP TABLE product;

CREATE TABLE product (
	product_id serial4 NOT NULL,
	"name" varchar(255) NOT NULL,
	description text NULL,
	price numeric(10, 2) NOT NULL,
	stock_quantity int4 NULL,
	CONSTRAINT product_pkey PRIMARY KEY (product_id)
);

-- Table Triggers

create trigger order_update_total_amount_trigger after
update
    on
    severstal.product for each row execute function severstal.order_update_total_amount_trigger_function();


-- severstal.shipment definition

-- Drop table

-- DROP TABLE shipment;

CREATE TABLE shipment (
	shipment_id serial4 NOT NULL,
	status varchar(50) NULL,
	CONSTRAINT shipment_pkey PRIMARY KEY (shipment_id)
);


-- severstal.deliveryaddress definition

-- Drop table

-- DROP TABLE deliveryaddress;

CREATE TABLE deliveryaddress (
	address_id serial4 NOT NULL,
	street varchar(255) NULL,
	city varchar(255) NULL,
	state varchar(255) NULL,
	postal_code varchar(15) NULL,
	country varchar(50) NULL,
	client_id int4 NULL,
	CONSTRAINT deliveryaddress_pkey PRIMARY KEY (address_id),
	CONSTRAINT deliveryaddress_fk FOREIGN KEY (client_id) REFERENCES client(client_id) ON DELETE CASCADE
);


-- severstal.orders definition

-- Drop table

-- DROP TABLE orders;

CREATE TABLE orders (
	order_id serial4 NOT NULL,
	client_id int4 NULL,
	manager_id int4 NULL,
	shipment_id int4 NULL,
	address_id int4 NULL,
	order_date date NULL,
	total_amount numeric(10, 2) NULL,
	CONSTRAINT orders_pkey PRIMARY KEY (order_id),
	CONSTRAINT orders_address_id_fkey FOREIGN KEY (address_id) REFERENCES deliveryaddress(address_id) ON DELETE CASCADE,
	CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES client(client_id) ON DELETE CASCADE,
	CONSTRAINT orders_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES manager(manager_id) ON DELETE CASCADE
);

-- Table Triggers

create trigger order_update_trigger after
update
    on
    severstal.orders for each row execute function severstal.order_update_trigger_function();
create trigger order_delete_trigger before
delete
    on
    severstal.orders for each row execute function severstal.order_delete_trigger_function();


-- severstal.ordershipment definition

-- Drop table

-- DROP TABLE ordershipment;

CREATE TABLE ordershipment (
	order_id int4 NOT NULL,
	shipment_id int4 NOT NULL,
	sipmentdate date NOT NULL DEFAULT '2023-01-01'::date,
	CONSTRAINT ordershipment_pkey PRIMARY KEY (order_id, shipment_id),
	CONSTRAINT ordershipment_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
	CONSTRAINT ordershipment_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES shipment(shipment_id) ON DELETE CASCADE
);


-- severstal.ordernote definition

-- Drop table

-- DROP TABLE ordernote;

CREATE TABLE ordernote (
	note_id serial4 NOT NULL,
	order_id int4 NULL,
	note_text text NULL,
	created_at timestamptz NULL,
	CONSTRAINT ordernote_pkey PRIMARY KEY (note_id),
	CONSTRAINT ordernote_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);


-- severstal.orderproduct definition

-- Drop table

-- DROP TABLE orderproduct;

CREATE TABLE orderproduct (
	order_id int4 NOT NULL,
	product_id int4 NOT NULL,
	counter int4 NOT NULL DEFAULT 1,
	CONSTRAINT orderproduct_pkey PRIMARY KEY (order_id, product_id),
	CONSTRAINT orderproduct_order_id_fkey FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
	CONSTRAINT orderproduct_product_id_fkey FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE
);

-- Table Triggers

create trigger order_update_total_amount_trigger after
update
    on
    severstal.orderproduct for each row execute function severstal.order_update_total_amount_trigger_function();



CREATE OR REPLACE FUNCTION severstal.order_delete_trigger_function()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    INSERT INTO severstal.OrderAudit (order_id, attribute_name, old_value, new_value, change_timestamp, manager_id)
    VALUES (OLD.order_id, 'DELETED', 'N/A', 'N/A', NOW(), pg_catalog."current_user"());

    RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION severstal.order_update_total_amount_trigger_function()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
UPDATE severstal.orders SET total_amount=(select sum(price* o.counter ) from severstal.product p 
 join severstal.orderproduct o on o.product_id = p.product_id 
where o.order_id =1) WHERE order_id=new.order_id;
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION severstal.order_update_trigger_function()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF OLD.client_id != NEW.client_id THEN
        INSERT INTO severstal.OrderAudit (order_id, attribute_name, old_value, new_value, change_timestamp, manager_id)
        VALUES (new.order_id, 'client_id', OLD.client_id::int4, NEW.client_id::int4, NOW(), pg_catalog."current_user"());
    END IF;

    IF OLD.order_date != NEW.order_date THEN
        INSERT INTO severstal.OrderAudit (order_id, attribute_name, old_value, new_value, change_timestamp, manager_id)
        VALUES (new.order_id, 'order_date', OLD.order_date::date, NEW.order_date::date, NOW(), pg_catalog."current_user"());
    END IF;

    IF OLD.shipment_id != NEW.shipment_id THEN
        INSERT INTO OrderAudit (order_id, attribute_name, old_value, new_value, change_timestamp, manager_id)
        VALUES (new.order_id, 'shipment_id', OLD.shipment_id::int4, NEW.shipment_id::int4, NOW(), pg_catalog."current_user"());
    END IF;
   
    IF OLD.address_id != NEW.address_id THEN
        INSERT INTO severstal.OrderAudit (order_id, attribute_name, old_value, new_value, change_timestamp, manager_id)
        VALUES (new.order_id, 'address_id', OLD.address_id::int4, NEW.address_id::int4, NOW(), pg_catalog."current_user"());
    END IF;
   
       IF OLD.manager_id != NEW.manager_id THEN
        INSERT INTO severstal.OrderAudit (order_id, attribute_name, old_value, new_value, change_timestamp, manager_id)
        VALUES (new.order_id, 'manager_id', OLD.manager_id::int4, NEW.manager_id::int4, NOW(), pg_catalog."current_user"());
    END IF;

    RETURN NEW;
END;
$function$
;


-- Таблица "Клиенты" (client)
INSERT INTO client ("name", contact_person, email, phone, address)
VALUES
  ('ООО Ромашка', 'Иван Петров', 'ivan@example.com', '123-456-7890', 'ул. Цветочная, 123'),
  ('ИП Иванов', 'Анна Иванова', 'anna@example.com', '987-654-3210', 'ул. Солнечная, 45'),
  ('ОАО СтройМастер', 'Петр Сидоров', 'petr@example.com', '777-888-9999', 'пр. Строителей, 67');

-- Таблица "Менеджеры" (manager)
INSERT INTO manager ("name", email, phone)
VALUES
  ('Иванов Иван Иванович', 'ivan.manager@example.com', '111-222-3333'),
  ('Петров Петр Петрович', 'petr.manager@example.com', '444-555-6666'),
  ('Сидоров Сидор Сидорович', 'sidor.manager@example.com', '777-888-9999');

-- Таблица "Товары" (product)
INSERT INTO product ("name", description, price, stock_quantity)
VALUES
  ('Ноутбук Dell XPS 13', 'Мощный ноутбук для профессионалов', 1500.00, 10),
  ('Смартфон iPhone 13 Pro', 'Премиум смартфон от Apple', 1200.00, 15),
  ('Планшет Samsung Galaxy Tab S7', 'Планшет с AMOLED-экраном', 700.00, 20);

-- Таблица "Адреса доставки" (deliveryaddress)
INSERT INTO deliveryaddress (street, city, state, postal_code, country, client_id)
VALUES
  ('ул. Лесная, 7', 'Москва', 'Московская область', '123456', 'Россия', 1),
  ('пр. Центральный, 34', 'Санкт-Петербург', 'Ленинградская область', '654321', 'Россия', 2),
  ('ул. Промышленная, 12', 'Екатеринбург', 'Свердловская область', '987654', 'Россия', 3);

-- Таблица "Заказы" (orders)
INSERT INTO orders (client_id, manager_id, shipment_id, address_id, order_date, total_amount)
VALUES
  (1, 1, NULL, 1, '2023-10-15', 0.00),
  (2, 2, NULL, 2, '2023-10-16', 0.00),
  (3, 3, NULL, 3, '2023-10-17', 0.00);

-- Таблица "Состав заказа" (orderproduct)
INSERT INTO orderproduct (order_id, product_id, counter)
VALUES
  (1, 1, 2),
  (1, 2, 3),
  (2, 2, 1),
  (3, 3, 5);

-- Таблица "Отгрузки" (shipment)
INSERT INTO shipment (status)
VALUES
  ('В обработке'),
  ('Отгружено'),
  ('Доставлено');

 
 INSERT INTO ordernote (order_id, note_text, created_at)
VALUES
  (1, 'Заметка к заказу №1', '2023-10-18 09:30:00+00'),
  (1, 'Важное уточнение', '2023-10-18 14:15:00+00'),
  (2, 'Примечание к заказу №2', '2023-10-17 11:45:00+00'),
  (3, 'Срочная заметка', '2023-10-19 08:00:00+00');
 
 INSERT INTO ordershipment (order_id, shipment_id, sipmentdate)
VALUES
  (1, 1, '2023-10-19'),
  (2, 2, '2023-10-20'),
  (3, 3, '2023-10-21');




