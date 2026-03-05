use GD2015C1
go

/* Implementar una regla de negocio en línea donde nunca una factura
nueva tenga un precio de producto distinto al que figura en la tabla
PRODUCTO. Registrar en una estructura adicional todos los casos
donde se intenta guardar un precio distinto. */

-- 1. Creación de la tabla
CREATE TABLE item_factura_rechazados (
	item_tipo char(1),
	item_sucursal char(4),
	item_numero char(8),
	item_producto char(8),
	item_cantidad decimal(12,2), -- Corregido a decimal
	item_precio decimal(12,2)
)
GO

-- 2. Trigger Set-Based
CREATE TRIGGER mismo_precio ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN

    -- A. Insertar en la tabla real SOLO los que coinciden el precio (Los correctos)
    INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT i.item_tipo, i.item_sucursal, i.item_numero, i.item_producto, i.item_cantidad, i.item_precio
    FROM inserted i 
    JOIN Producto p ON p.prod_codigo = i.item_producto
    WHERE i.item_precio = p.prod_precio;

    -- B. Insertar en la tabla de rechazos SOLO los diferentes (Los incorrectos)
    INSERT INTO item_factura_rechazados (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT i.item_tipo, i.item_sucursal, i.item_numero, i.item_producto, i.item_cantidad, i.item_precio
    FROM inserted i 
    JOIN Producto p ON p.prod_codigo = i.item_producto
    WHERE i.item_precio <> p.prod_precio;
END
GO