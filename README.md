--------------------------------------------------------------------------------
# 📖 Guía T-SQL 
---

## 1. ESTRUCTURAS (Inserts, Updates, Deletes)

El enfoque principal debe ser siempre **Set-Based**

### INSERT
**Inserción simple:**
```sql
INSERT INTO Tabla (col1, col2) VALUES (val1, val2);
Inserción Masiva (Desde otra tabla/subselect):
INSERT INTO Tabla_Destino (col1, col2)
SELECT colA, colB 
FROM Tabla_Origen
WHERE condicion = 1;
UPDATE
Siempre vincular con un JOIN a la tabla original o usar tablas conceptuales (inserted/deleted) si estás en un trigger.
UPDATE t
SET t.columna = t.columna + 1
FROM Tabla_Destino t
JOIN Otra_Tabla o ON t.id = o.id
WHERE o.condicion = 'Cumple';
DELETE
Borrado masivo utilizando subconsultas o NOT EXISTS.
DELETE FROM Tabla
WHERE id NOT IN (SELECT id_valido FROM Otra_Tabla);
Borrado de duplicados exactos usando CTE (Expresiones de Tabla Comunes):
WITH CTE_Duplicados AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY col_clave ORDER BY (SELECT NULL)) as fila_num
    FROM Tabla
)
DELETE FROM CTE_Duplicados WHERE fila_num > 1

--------------------------------------------------------------------------------
2. RESTRICCIONES (PKs y FKs)
Crear / Setear Primary Keys y Foreign Keys

ALTER TABLE Item_Factura
ADD CONSTRAINT PK_Item_Factura PRIMARY KEY (item_tipo, item_sucursal, item_numero, item_producto)

-- Agregar Foreign Key
ALTER TABLE Item_Factura
ADD CONSTRAINT FK_Item_Factura_Factura FOREIGN KEY (item_tipo, item_sucursal, item_numero) 
REFERENCES Factura (fact_tipo, fact_sucursal, fact_numero)

Modificar FKs o PKs
ALTER TABLE Tabla DROP CONSTRAINT Nombre_De_La_Constraint

Crear la nueva
ALTER TABLE Tabla ADD CONSTRAINT Nuevo_Nombre FOREIGN KEY (columna) REFERENCES Otra_Tabla(columna)

--------------------------------------------------------------------------------
3. OBJETOS PROGRAMABLES
A. FUNCTION
Las funciones NO pueden modificar el estado de los datos (ni INSERT, UPDATE o DELETE) Siempre deben devolver un valor obligatoriamente.

CREATE FUNCTION dbo.fn_CalcularAlgo (@param1 int, @param2 char(8))
RETURNS decimal(12,2) -- Lo que retorna
AS
BEGIN
    DECLARE @resultado decimal(12,2)
    
    SELECT @resultado = prod_precio * @param1
    FROM Producto 
    WHERE prod_codigo = @param2

    RETURN ISNULL(@resultado, 0); -- Última instrucción siempre
END
GO

B. PROCEDURE
SÍ pueden modificar datos. Para devolver resultados calculados se usan parámetros OUTPUT.

CREATE PROCEDURE SP_Ejemplo (
    @id_cliente char(6),
    @cantidad_compras int OUTPUT -- Variable de salida
)
AS
BEGIN
    -- Operación o cálculo
    SELECT @cantidad_compras = COUNT(*) 
    FROM Factura 
    WHERE fact_cliente = @id_cliente
END
GO

CURSORES: última opción solo si necesitas darle un tratamiento diferente y específico a cada fila que un UPDATE/INSERT masivo no puede resolver.

DECLARE @variable_receptora char(8)
-- 1. DECLARAR
DECLARE mi_cursor CURSOR FOR
    SELECT columna FROM Tabla WHERE condicion = 1
-- 2. ABRIR
OPEN mi_cursor
-- 3. PRIMER FETCH
FETCH NEXT FROM mi_cursor INTO @variable_receptora
-- 4. RECORRER
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Lógica fila por fila aquí...
    
    -- SIGUIENTE FETCH (Fundamental antes del END)
    FETCH NEXT FROM mi_cursor INTO @variable_receptora
END

-- 5. CERRAR Y LIBERAR
CLOSE mi_cursor
DEALLOCATE mi_cursor

--------------------------------------------------------------------------------
4. TRIGGERS (El núcleo del Parcial)
Un trigger intercepta operaciones (INSERT, UPDATE, DELETE) de forma automática. Utiliza dos tablas virtuales conceptuales en la memoria: inserted y deleted.

AFTER
Se usa para controlar / restringir una acción. El motor primero hace el intento de insert/update/delete y el trigger evalúa.
CREATE TRIGGER trg_Control ON Tabla AFTER INSERT, UPDATE
AS
BEGIN
    -- Lógica de Conjunto evaluando la tabla "inserted"
    IF EXISTS(SELECT 1 FROM inserted i JOIN ... WHERE condicion = 'Inválida')
    BEGIN
        RAISERROR('Mensaje de error para el usuario', 16, 1)
        ROLLBACK TRAN
    END
END
GO

INSTEAD OF (En lugar de)
Se usa cuando necesitas un tratamiento particular (por ejemplo: "Dejar entrar a los que cumplen la regla, y derivar a una tabla de rechazos a los que no"). Anula la instrucción original.
CREATE TRIGGER trg_Tratamiento_Particular ON Tabla INSTEAD OF INSERT
AS
BEGIN
    -- 1. Dejar entrar a los válidos a la tabla original
    INSERT INTO Tabla (cols...)
    SELECT cols FROM inserted i WHERE i.valido = 1

    -- 2. Derivar los inválidos a tabla auxiliar/rechazos
    INSERT INTO Tabla_Rechazos (cols...)
    SELECT cols FROM inserted i WHERE i.valido = 0
END
GO

--------------------------------------------------------------------------------
5. ÍNDICES CLUSTERED: para acceso optimizado

CREATE CLUSTERED INDEX IX_NombreIndice 
ON Tabla (Columna1 ASC, Columna2 DESC);

-- Eliminar un índice
DROP INDEX IX_NombreIndice ON Tabla;
