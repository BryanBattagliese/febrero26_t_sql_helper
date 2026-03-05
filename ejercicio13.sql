USE GD2015C1
GO

/* 1. Implementar una regla de negocio en línea que al realizar una venta (SOLO INSERCION) permita componer los productos descompuestos, es decir, 
si se guardan en la factura 2 hamb. 2 papas 2 gaseosas se deberá guardar en la factura 2 (DOS) COMBO |. Si 1 combo 1 equivale a: 1 hamb. 1 papa y 1 gaseosa. 
Nota: Considerar que cada vez que se guardan los items, se mandan todos los productos de ese item a la vez, y no de manera parcial. */

CREATE PROCEDURE dbo.SP_UNIFICAR_PRODUCTO
AS
BEGIN

    DECLARE @combo         CHAR(8)
    DECLARE @combocantidad INT

    DECLARE @fact_tipo CHAR(1)
    DECLARE @fact_suc  CHAR(4)
    DECLARE @fact_nro  CHAR(8)

    ---------------------------------------------------------
    -- Cursor de facturas: recorre todas las facturas
    ---------------------------------------------------------
    DECLARE cFacturas CURSOR FOR
        SELECT fact_tipo, fact_sucursal, fact_numero
        FROM   Factura

    OPEN cFacturas
    FETCH NEXT FROM cFacturas INTO @fact_tipo, @fact_suc, @fact_nro

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -----------------------------------------------------
        -- Cursor de combos posibles dentro de ESA factura
        -----------------------------------------------------
        DECLARE cProducto CURSOR FOR
            SELECT C1.comp_producto
            FROM   Item_Factura I
                   JOIN Composicion C1
                     ON I.item_producto = C1.comp_componente
            WHERE  I.item_sucursal = @fact_suc
              AND  I.item_numero   = @fact_nro
              AND  I.item_tipo     = @fact_tipo
              AND  I.item_cantidad >= C1.comp_cantidad
            GROUP BY C1.comp_producto
            HAVING COUNT(*) = (
                     SELECT COUNT(*)
                     FROM   Composicion C2
                     WHERE  C2.comp_producto = C1.comp_producto
                   )

        OPEN cProducto
        FETCH NEXT FROM cProducto INTO @combo;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -------------------------------------------------
            -- Cuántos combos completos puedo armar
            -------------------------------------------------
            SELECT @combocantidad =
                   MIN( FLOOR( I.item_cantidad * 1.0 / C1.comp_cantidad ) )
            FROM   Item_Factura I
                   JOIN Composicion C1
                     ON I.item_producto = C1.comp_componente
            WHERE  I.item_sucursal = @fact_suc
              AND  I.item_numero   = @fact_nro
              AND  I.item_tipo     = @fact_tipo
              AND  I.item_cantidad >= C1.comp_cantidad
              AND  C1.comp_producto = @combo;

            IF @combocantidad IS NOT NULL AND @combocantidad > 0
            BEGIN
                -------------------------------------------------
                -- 1) Insertar la fila del combo en Item_Factura
                -------------------------------------------------
                INSERT INTO Item_Factura
                    (item_tipo, item_sucursal, item_numero,
                     item_producto, item_cantidad, item_precio)
                SELECT @fact_tipo,
                       @fact_suc,
                       @fact_nro,
                       @combo,
                       @combocantidad,
                       @combocantidad * P.prod_precio
                FROM   Producto P
                WHERE  P.prod_codigo = @combo;

                -------------------------------------------------
                -- 2) Descontar cantidades de componentes
                --    y recalcular su precio
                -------------------------------------------------
                UPDATE I1
                SET    item_cantidad = I1.item_cantidad
                                      - @combocantidad * C1.comp_cantidad,
                       item_precio   = (I1.item_cantidad
                                        - @combocantidad * C1.comp_cantidad)
                                        * P.prod_precio
                FROM   Item_Factura I1
                       JOIN Composicion C1
                         ON I1.item_producto = C1.comp_componente
                       JOIN Producto P
                         ON P.prod_codigo = I1.item_producto
                WHERE  I1.item_sucursal = @fact_suc
                  AND  I1.item_numero   = @fact_nro
                  AND  I1.item_tipo     = @fact_tipo
                  AND  C1.comp_producto = @combo;

                -------------------------------------------------
                -- 3) Borrar ítems que quedaron en 0
                -------------------------------------------------
                DELETE FROM Item_Factura
                WHERE  item_sucursal = @fact_suc
                  AND  item_numero   = @fact_nro
                  AND  item_tipo     = @fact_tipo
                  AND  item_cantidad <= 0;
            END;

            FETCH NEXT FROM cProducto INTO @combo;
        END;

        CLOSE cProducto;
        DEALLOCATE cProducto;

        FETCH NEXT FROM cFacturas INTO @fact_tipo, @fact_suc, @fact_nro;
    END;

    CLOSE cFacturas;
    DEALLOCATE cFacturas;
END;
GO