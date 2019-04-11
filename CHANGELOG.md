# v2.4.0

## Updated deps
  * `esqlite` ~> 0.4

# v2.3.0

## Bug fixes
  * Fix the following logger meta not being saved to the databse:
    * `:module`
    * `:function`
    * `:file`
    * `:line`
    * `:registered_name`

## Updated deps
  * `esqlite` ~> 0.3
  * `ex_doc` ~> 0.20

# v2.2.0

## Bug fixes
  * Fix bad math in circular buffer system.

# v2.1.0

## Enhancements
  * add a "circular buffer" system to clean up old logs after a certain amount
    of logs are created.

# v2.0.1

Rerelease v2.0.0 with updated description

# v2.0.0

Initial release
