USE GD2015C1
GO

/* Se agregó recientemente un campo CUIT a la tabla de clientes. Debido a un
error, se generaron múltiples registros de clientes con el mismo CUIT.
Se deberá desarrollar un algoritmo de depuración de datos que identifique y corrija
estos duplicados, manteniendo un único registro por CUIT. Será necesario definir un
criterio de selección para determinar qué registro conservar y cuáles eliminar.
Adicionalmente, se deberá implementar una restricción que impida la creación futura
de registros con CUIT duplicado. */

-- 1. Si la consigna exige agregarlo (aunque dice "se agregó recientemente"):
ALTER TABLE cliente ADD clie_cuit char(13);
GO

-- 2. ELIMINACIÓN SET-BASED: Borramos todos los que NO sean el código mínimo de cada CUIT
DELETE FROM Cliente
WHERE clie_cuit IS NOT NULL AND clie_codigo NOT IN (
      
      -- Este subselect aísla los registros que SÍ vamos a conservar (criterio: menor código)
      SELECT MIN(clie_codigo)
      FROM Cliente
      WHERE clie_cuit IS NOT NULL
      GROUP BY clie_cuit
  )
GO

-- 3. Agregamos la restricción única
ALTER TABLE Cliente ADD CONSTRAINT UQ_Cliente_Cuit UNIQUE(clie_cuit)
GO