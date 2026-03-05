USE GD2015C1
GO
/*
"Se requiere mantener precalculada toda la informacion relacionada con las ventas, de modo que pueda
 consultarse de forma rapida y eficiente.
 La información debe incluir para cada combinación de mes, anio y producto:
 + Cantidad total vendida
 + Precio MAX venta
 + Precio MIN venta
 + Cliente que mas compro (cantidad)

 Garantizar que la info este disponible y actualizada, reflejando los datos de ventas.
 Permitir un acceso optimizado a las consultas filtradas por mes y año."			
*/


--Creo una tabla para guardar la información pedida
CREATE TABLE Ventas_Realizadas (mes_anio CHAR(6), 
                                cod_prod CHAR(8),  
                                cant_total_vendida INT, 
								precio_max DECIMAL(12,2), 
								precio_min DECIMAL(12,2), 
								mejor_cliente CHAR(8),
								cant_comprada_mejor_cliente INT)
GO

-- Migración inicial de datros:
INSERT INTO Ventas_Realizadas (mes_anio, cod_prod, cant_total_vendida, precio_max, precio_min, mejor_cliente, cant_comprada_mejor_cliente)
SELECT 
    CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha)),
    i.item_producto,
    SUM(i.item_cantidad),
    MAX(i.item_precio),
    MIN(i.item_precio),
    
    -- Subselect para el Mejor Cliente histórico de ese mes/producto
    (SELECT TOP 1 f2.fact_cliente
     FROM Factura f2
     JOIN Item_Factura i2 ON i2.item_numero = f2.fact_numero AND i2.item_sucursal = f2.fact_sucursal AND i2.item_tipo = f2.fact_tipo
     WHERE CONCAT(YEAR(f2.fact_fecha), MONTH(f2.fact_fecha)) = CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha))
       AND i2.item_producto = i.item_producto
     GROUP BY f2.fact_cliente
     ORDER BY SUM(i2.item_cantidad) DESC),
     
    -- Subselect para la cantidad del Mejor Cliente histórico
    (SELECT TOP 1 SUM(i2.item_cantidad)
     FROM Factura f2
     JOIN Item_Factura i2 ON i2.item_numero = f2.fact_numero AND i2.item_sucursal = f2.fact_sucursal AND i2.item_tipo = f2.fact_tipo
     WHERE CONCAT(YEAR(f2.fact_fecha), MONTH(f2.fact_fecha)) = CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha))
       AND i2.item_producto = i.item_producto
     GROUP BY f2.fact_cliente
     ORDER BY SUM(i2.item_cantidad) DESC)
FROM Factura f
JOIN Item_Factura i ON f.fact_numero = i.item_numero AND f.fact_sucursal = i.item_sucursal AND f.fact_tipo = i.item_tipo
GROUP BY CONCAT(YEAR(f.fact_fecha), MONTH(f.fact_fecha)), i.item_producto;
GO

--Para estar siempre actualizada, al detectar una venta cargo la informacion en la nueva tabla 
CREATE TRIGGER nueva_venta ON Item_Factura
AFTER INSERT, UPDATE
AS 
BEGIN
           --updateo con esa nueva venta donde existe ese periodo/producto
		   UPDATE v SET v.cant_total_vendida = cant_total_vendida + i.item_cantidad,
		                v.precio_max = CASE WHEN i.item_precio > v.precio_max THEN i.item_precio 
                                       ELSE v.precio_max
                                       END,
						v.precio_min = CASE WHEN i.item_precio < v.precio_min THEN i.item_precio 
                                       ELSE v.precio_min
                                       END,
						v.mejor_cliente = CASE WHEN i.item_cantidad > v.cant_comprada_mejor_cliente THEN f.fact_cliente
                                       ELSE v.mejor_cliente
                                       END,
						v.cant_comprada_mejor_cliente = CASE WHEN i.item_cantidad > v.cant_comprada_mejor_cliente THEN i.item_cantidad
                                       ELSE v.cant_comprada_mejor_cliente
                                       END
		   FROM Ventas_Realizadas v JOIN inserted i ON v.cod_prod = i.item_producto
		                            JOIN Factura f ON i.item_numero =  f.fact_numero AND i.item_sucursal = f.fact_sucursal AND f.fact_tipo = i.item_tipo
								    WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha),MONTH(f.fact_fecha))
 
            -- Inserto la nueva venta donde aun no existe ese periodo/produto
            INSERT INTO Ventas_Realizadas(mes_anio, cod_prod, cant_total_vendida, precio_max, precio_min, mejor_cliente, cant_comprada_mejor_cliente)
			   SELECT
			   CONCAT(MONTH(fact_fecha), YEAR(f.fact_fecha)) AS mes_anio,
			   i.item_producto AS cod_prod,
			   i.item_cantidad AS cant_total_vendida,
			   i.item_precio AS precio_max,
		       i.item_precio AS precio_min,
			   f.fact_cliente AS mejor_cliente,
			   i.item_cantidad AS cant_comprada_mejor_cliente
			   FROM inserted i JOIN Factura f ON i.item_numero =  f.fact_numero AND i.item_sucursal = f.fact_sucursal AND f.fact_tipo = i.item_tipo
			 WHERE NOT EXISTS (SELECT 1 FROM Ventas_Realizadas v WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha),MONTH(f.fact_fecha))
			                                                     AND v.cod_prod = i.item_producto)

            -- Logica para el DELETE
            IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
            BEGIN
                UPDATE v SET 
                    -- 1. Restamos la cantidad que se acaba de eliminar
                    v.cant_total_vendida = v.cant_total_vendida - d.item_cantidad,
            
                    -- 2. Recalculamos los topes y máximos mediante subselects. 
                    -- Como vimos, es imposible saber si el registro que borraron era el récord máximo/mínimo 
                    -- sin volver a leer la tabla original para ese mes y producto.
                    v.precio_max = (SELECT MAX(i2.item_precio) 
                                    FROM Item_Factura i2 JOIN Factura f2 ON i2.item_numero = f2.fact_numero 
                                    AND i2.item_sucursal = f2.fact_sucursal 
                                    AND i2.item_tipo = f2.fact_tipo 
                                    WHERE i2.item_producto = v.cod_prod AND CONCAT(YEAR(f2.fact_fecha),MONTH(f2.fact_fecha)) = v.mes_anio),
                    v.precio_min = (SELECT MIN(i2.item_precio) 
                                    FROM Item_Factura i2 JOIN Factura f2 ON i2.item_numero = f2.fact_numero 
                                    AND i2.item_sucursal = f2.fact_sucursal 
                                    AND i2.item_tipo = f2.fact_tipo 
                                    WHERE i2.item_producto = v.cod_prod AND CONCAT(YEAR(f2.fact_fecha),MONTH(f2.fact_fecha)) = v.mes_anio),
                    v.mejor_cliente = (SELECT TOP 1 f2.fact_cliente 
                                        FROM Factura f2 JOIN Item_Factura i2 ON i2.item_numero = f2.fact_numero 
                                        AND i2.item_sucursal = f2.fact_sucursal 
                                        AND i2.item_tipo = f2.fact_tipo 
                                        WHERE i2.item_producto = v.cod_prod AND CONCAT(YEAR(f2.fact_fecha),MONTH(f2.fact_fecha)) = v.mes_anio 
                                        GROUP BY f2.fact_cliente 
                                        ORDER BY SUM(i2.item_cantidad) DESC),
                    v.cant_comprada_mejor_cliente = (SELECT TOP 1 SUM(i2.item_cantidad) 
                                                    FROM Factura f2 JOIN Item_Factura i2 ON i2.item_numero = f2.fact_numero 
                                                    AND i2.item_sucursal = f2.fact_sucursal 
                                                    AND i2.item_tipo = f2.fact_tipo 
                                                    WHERE i2.item_producto = v.cod_prod AND CONCAT(YEAR(f2.fact_fecha),MONTH(f2.fact_fecha)) = v.mes_anio 
                                                    GROUP BY f2.fact_cliente 
                                                    ORDER BY SUM(i2.item_cantidad) DESC)
                FROM Ventas_Realizadas v 
                JOIN deleted d ON v.cod_prod = d.item_producto 
                JOIN Factura f ON d.item_numero = f.fact_numero AND d.item_sucursal = f.fact_sucursal AND f.fact_tipo = d.item_tipo
                WHERE v.mes_anio = CONCAT(YEAR(f.fact_fecha),MONTH(f.fact_fecha))
            END
END
GO

--Para acceso optimizado, creo un indice por mes y año
CREATE CLUSTERED INDEX idx_mes_anio ON Ventas_Realizadas(mes_anio)