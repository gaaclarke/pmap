## 0.3.0

* Fix an issue that lets the `pmap` fail if the results need to be sorted.
* Add an optional `preserveOrder` option to ignore order and faster get new values from the stream. (default is `true`, making the API surface downward compatible)
* Create an `mapParallel` extension method for `Iterable`s.
* Test whether all the iterable elements are successfully processed. Otherwise throw a `StateError`.
* Migrate to nullsafety.

## 0.2.1

* Added unit tests fixed error for parallel > 2

## 0.2.0

* Made the results for parallel > 2 ordered.

## 0.1.0

* Initial release - pmap results can be out of order for parallel > 1.
