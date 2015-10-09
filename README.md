# inctix


setup "desks" table:

```mysql
CREATE TABLE `desks` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `domain` varchar(128) DEFAULT NULL,
  `user` varchar(128) DEFAULT NULL,
  `token` varchar(128) DEFAULT NULL,
  `last_timestamp` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
```