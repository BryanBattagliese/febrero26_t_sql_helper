/*
Se requiere garantizar la consistencia de la base de datos respecto de la relación entre productos y sus componentes. 
Un producto perteneciente a los rubros '0001', '0002', '0003' no puede estar compuesto por ningun producto de los rubros  '0004', '0005', '0006'. 
Actualmente existen registros en la base de datos que no cumplen con esta regla, hay inconsistencias: 

1. Detectar los registros inconsistentes 
2. Decidir y aplicar una estrategia para resolver inconsistencias 
3. Implementar una restriccion o mecanismo que impida que vuelvan a generar inconsistencias en el futuro
*/

-- Mi decision en este caso es la de eliminar los registros que no cumplen con la regla de negocio.
DELETE c
FROM Composicion c join Producto ppadre on ppadre.prod_codigo = c.comp_producto
				   join Producto phijo on phijo.prod_codigo = c.comp_componente
WHERE ppadre.prod_rubro IN ('0001','0002','0003') AND phijo.prod_rubro IN ('0004','0005','0006')
GO

-- Creo un trigger para evitar que esto suceda en el futuro.
CREATE TRIGGER recuperatorio1 ON Composicion AFTER insert, update
AS
BEGIN

	IF EXISTS(
		SELECT 1
		FROM Inserted c join Producto ppadre on ppadre.prod_codigo = c.comp_producto
						join Producto phijo on phijo.prod_codigo = c.comp_componente
		WHERE ppadre.prod_rubro IN ('0001','0002','0003') AND phijo.prod_rubro IN ('0004','0005','0006')
	)

	BEGIN
		PRINT 'Error de Negocio: Un producto de rubro 0001, 0002 o 0003 no puede tener componentes de los rubros 0004, 0005 o 0006.'
        ROLLBACK TRANSACTION
	END

END
GO