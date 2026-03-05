USE GD2015C1
GO

/* Implementar una regla de negocio de validación en línea que permita validar el STOCK al realizarse una venta. 
Cada venta se debe descontar sobre el depósito 00. En caso de que se venda un producto compuesto, 
el descuento de stock se debe realizar por sus componentes. Si no hay STOCK para ese artículo, no se deberá guardar ese artículo, 
pero si los otros en los cuales hay stock positivo.
Es decir, solamente se deberán guardar aquellos para los cuales si hay stock, sin guardarse los que no poseen cantidades suficientes.
*/

CREATE TRIGGER EJERCICIO9 ON ITEM_FACTURA INSTEAD OF INSERT
AS
BEGIN

	-- A. Filtramos y insertamos SOLO los PRODUCTOS SIMPLES que tienen stock
	INSERT INTO Item_Factura(item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT I.item_tipo, I.item_sucursal, I.item_numero, I.item_producto, I.item_cantidad, I.item_precio 
	FROM inserted I JOIN Producto P ON P.prod_codigo = i.item_producto JOIN STOCK s on s.stoc_producto = i.item_producto
	WHERE (s.stoc_cantidad >= i.item_cantidad) and (s.stoc_deposito = '00') and not exists(select 1 from Composicion c where c.comp_producto = i.item_producto)

    -- A2. Descontamos el STOCK de los PRODUCTOS SIMPLES
    UPDATE s SET s.stoc_cantidad = s.stoc_cantidad - i.item_cantidad
    FROM STOCK s JOIN inserted i ON s.stoc_producto = i.item_producto
    -- Este JOIN con la tabla real verifica que el producto haya se haya insertado!!!  
    JOIN Item_Factura f ON f.item_tipo = i.item_tipo AND f.item_sucursal = i.item_sucursal AND f.item_numero = i.item_numero AND f.item_producto = i.item_producto
    WHERE (s.stoc_deposito = '00') AND (i.item_producto NOT IN (SELECT comp_producto FROM Composicion))

    ---------------------------------------------------------------------------------------------------------------------
	-- B. Filtramos y insertamos SOLO los PRODUCTOS COMPUESTOS que tienen stock para todos sus componentes
	INSERT INTO Item_Factura(item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT I.item_tipo, I.item_sucursal, I.item_numero, I.item_producto, I.item_cantidad, I.item_precio 
	FROM inserted I
	WHERE I.item_producto IN (SELECT comp_producto FROM Composicion) -- Nos aseguramos que sea Compuesto
      
      AND 
      -- Contamos cuántos componentes lleva la receta original
      (SELECT COUNT(*) FROM Composicion WHERE comp_producto = I.item_producto) 
           
      = 
      -- Lo igualamos a la cantidad de sus componentes que SÍ tienen stock suficiente
      (SELECT COUNT(*) 
       FROM Composicion C 
       JOIN STOCK S ON S.stoc_producto = C.comp_componente
       WHERE C.comp_producto = I.item_producto 
       AND S.stoc_deposito = '00' 
       AND S.stoc_cantidad >= (I.item_cantidad * C.comp_cantidad))

        -- B2. Descontar a los componentes de los COMPUESTOS que lograron entrar
        UPDATE s SET s.stoc_cantidad = s.stoc_cantidad - (i.item_cantidad * c.comp_cantidad)
        FROM STOCK s JOIN Composicion c ON s.stoc_producto = c.comp_componente
        JOIN inserted i ON c.comp_producto = i.item_producto
        -- Este JOIN con la tabla real verifica que el producto haya se haya insertado!!!  
        JOIN Item_Factura f ON f.item_tipo = i.item_tipo AND f.item_sucursal = i.item_sucursal AND f.item_numero = i.item_numero AND f.item_producto = i.item_producto
        WHERE s.stoc_deposito = '00'

END
GO