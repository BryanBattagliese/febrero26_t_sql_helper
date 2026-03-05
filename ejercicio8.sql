/*
Implementar una regla de negocio en línea donde 
nunca una factura nueva tenga un precio de producto distinto al que figura en la tabla PRODUCTO. 
Registrar en una estructura adicional todos los casos donde se intenta guardar un precio distinto.
*/

CREATE TABLE item_factura_rechazados (
	item_tipo char(1),
	item_sucursal char(4),
	item_numero char(8),
	item_producto char(8),
	item_cantidad decimal(12,2), 
	item_precio decimal(12,2)
)
GO

CREATE TRIGGER EJERCICIO9 ON ITEM_FACTURA instead of INSERT
AS
BEGIN

  -- A. Filtramos y mandamos a la tabla de RECHAZADOS SOLO los del precio distinto
    INSERT INTO item_factura_rechazados (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT I.item_tipo, I.item_sucursal, I.item_numero, I.item_producto, I.item_cantidad, I.item_precio 
    FROM inserted I 
    JOIN Producto P ON P.prod_codigo = I.item_producto
    WHERE I.item_precio <> P.prod_precio

    -- B. Filtramos y mandamos a la tabla REAL (Item_Factura) SOLO los del precio correcto
    INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT I.item_tipo, I.item_sucursal, I.item_numero, I.item_producto, I.item_cantidad, I.item_precio 
    FROM inserted I 
    JOIN Producto P ON P.prod_codigo = I.item_producto
    WHERE I.item_precio = P.prod_precio
END