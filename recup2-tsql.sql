USE GD2015C1
GO

/* Se creo una tabla ventas cuyos campos son periodo(yyyymm), producto, cliente, cantidad unidades, precio promedio. 
Por un error, se ejecuto un update sobre ventas y dejo los años impares con las cantidades incorrectas. 
Debera arreglar dicha información e implementar una logica para que siempre quede actualizada con la informacion pertinente.			 */

-- Estructura de la tabla ventas
CREATE TABLE VentasRECUP2 (
	mes_anio char(6), 
	producto char(8), 
	cliente char(6),
	cantidad decimal(12,2),
	precio_prom decimal(12,2)
)
GO

-- Elimino las ventas de años impares, que no son consistentes
DELETE v
FROM VentasRECUP2 v
WHERE CAST(LEFT(v.mes_anio, 4) AS INT) % 2 <> 0
GO

-- Arreglo los años impares con información consistente
INSERT INTO VentasRECUP2(mes_anio, producto, cliente, cantidad, precio_prom)
SELECT
	CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha)),
	i.item_producto,
	f.fact_cliente,
	SUM(i.item_cantidad),
	AVG(i.item_precio)
FROM Factura f 
JOIN Item_Factura i ON f.fact_numero = i.item_numero AND f.fact_sucursal = i.item_sucursal AND f.fact_tipo = i.item_tipo
WHERE YEAR(f.fact_fecha) % 2 <> 0
GROUP BY CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha)), i.item_producto, f.fact_cliente
GO

-- Creo un trigger para evitar que esto suceda en el futuro. Y mantener las ventas consistentes
CREATE TRIGGER recuperatorio2 ON Item_Factura AFTER INSERT, UPDATE, DELETE
AS
BEGIN

	-- BLOQUE 1: CASO INSERT Y UPDATE
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
	    
		-- UPDATE donde YA exista el periodo: recalculo con subconsultas exactas para ese periodo/producto/cliente
	    UPDATE v SET 
		    v.cantidad = (
                SELECT SUM(i2.item_cantidad) 
                FROM Item_Factura i2 
                JOIN Factura f2 ON i2.item_numero=f2.fact_numero AND i2.item_sucursal=f2.fact_sucursal AND i2.item_tipo=f2.fact_tipo
                WHERE CONCAT(YEAR(f2.fact_fecha), MONTH(f2.fact_fecha)) = v.mes_anio AND i2.item_producto = v.producto AND f2.fact_cliente = v.cliente
            ),
		    v.precio_prom = (
                SELECT AVG(i2.item_precio) 
                FROM Item_Factura i2 
                JOIN Factura f2 ON i2.item_numero=f2.fact_numero AND i2.item_sucursal=f2.fact_sucursal AND i2.item_tipo=f2.fact_tipo
                WHERE CONCAT(YEAR(f2.fact_fecha), MONTH(f2.fact_fecha)) = v.mes_anio AND i2.item_producto = v.producto AND f2.fact_cliente = v.cliente
            )
	    FROM VentasRECUP2 v 
        JOIN inserted i ON v.producto = i.item_producto
	    JOIN Factura f ON i.item_numero=f.fact_numero AND i.item_sucursal=f.fact_sucursal AND f.fact_tipo=i.item_tipo
	    WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha))
		  AND f.fact_cliente = v.cliente
	
	    -- INSERT donde NO exista el periodo: le agregamos el GROUP BY para que compile el AVG() y agrupe lotes de inserted
	    INSERT INTO VentasRECUP2(mes_anio, producto, cliente, cantidad, precio_prom)
	    SELECT
		    CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha)) AS mes_anio,
		    i.item_producto,
		    f.fact_cliente,
		    SUM(i.item_cantidad),
		    AVG(i.item_precio)
	    FROM inserted i 
        JOIN Factura f ON i.item_numero=f.fact_numero AND i.item_sucursal=f.fact_sucursal AND f.fact_tipo=i.item_tipo
	    WHERE NOT EXISTS(
		    SELECT 1 
		    FROM VentasRECUP2 v 
		    WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha)) AND v.producto = i.item_producto AND v.cliente = f.fact_cliente
	    )
        GROUP BY CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha)), i.item_producto, f.fact_cliente
    END
	

    -- BLOQUE 2: CASO DELETE PURO
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN
	    UPDATE v SET
		    v.cantidad = (
                SELECT SUM(i2.item_cantidad) 
                FROM Item_Factura i2 
                JOIN Factura f2 ON i2.item_numero=f2.fact_numero AND i2.item_sucursal=f2.fact_sucursal AND i2.item_tipo=f2.fact_tipo
                WHERE CONCAT(YEAR(f2.fact_fecha), MONTH(f2.fact_fecha)) = v.mes_anio AND i2.item_producto = v.producto AND f2.fact_cliente = v.cliente
            ),
		    v.precio_prom = (
                SELECT AVG(i2.item_precio) 
                FROM Item_Factura i2 
                JOIN Factura f2 ON i2.item_numero=f2.fact_numero AND i2.item_sucursal=f2.fact_sucursal AND i2.item_tipo=f2.fact_tipo
                WHERE CONCAT(YEAR(f2.fact_fecha), MONTH(f2.fact_fecha)) = v.mes_anio AND i2.item_producto = v.producto AND f2.fact_cliente = v.cliente
            )
	    FROM VentasRECUP2 v 
        JOIN deleted d ON v.producto = d.item_producto
	    JOIN Factura f ON d.item_numero=f.fact_numero AND d.item_sucursal=f.fact_sucursal AND d.item_tipo=d.item_tipo
	    WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha)) AND f.fact_cliente = v.cliente

        -- Si la cantidad de ventas de ese producto bajo a cero tras el DELETED, se limpia la estadística
        DELETE FROM VentasRECUP2 WHERE cantidad IS NULL OR cantidad = 0
    END
END
GO