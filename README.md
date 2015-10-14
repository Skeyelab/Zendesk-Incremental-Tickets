# inctix

This project is very much in works and most of the documentation, if any, is out of date.  The scripts however, kick ass.



setup "desks" table:

```sql
CREATE TABLE `desks` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `domain` varchar(128) DEFAULT NULL,
  `user` varchar(128) DEFAULT NULL,
  `token` varchar(128) DEFAULT NULL,
  `last_timestamp` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
```
