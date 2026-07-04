extends Node
## Autoload (GameConfig): parametros globales de los sistemas de juego
## (suciedad, naturaleza y construcciones historicas).

## Casas minimas dentro de una ventana de 3x3 para que esa ventana completa
## (sus 9 tiles) se vuelva suciedad.
var dirt_house_threshold := 4

## Lado del area (NxN) que purifica cada tile de limpieza, centrada en el.
var clean_size := 5

## Cada cuantas casas colocadas se exige un grupo de naturaleza.
var nature_per_houses := 4

## Naturalezas exigidas por cada grupo de casas.
var nature_amount := 2

## Lado del tile de naturaleza (NxN).
var nature_size := 1

## Lado de las construcciones historicas (NxN).
var historic_size := 5

## Lado (en tiles) del footprint visual de la estatua (ocupa una tile de 1x1).
var statue_size := 1.0

## Altura (en metros) a la que se apoya la estatua sobre el terreno.
var statue_offset_y := 0.0

## Turistas totales necesarios para desbloquear la primera historica.
var historic_tourists_1 := 70

## Turistas adicionales (despues de la primera) para la segunda (400 total).
var historic_tourists_2 := 330

## Turistas adicionales (despues de la segunda) para la tercera (2000 total).
var historic_tourists_3 := 1600
