# Zendesk Incremental Tickets to MySQL

This will pull incremental ticket data into a MySQL data base for one or multiple Zendesk accounts.  Each account will be in its own table in the database and columns will be added as needed. 

If multiple accounts are added, it will respect everyone's API limits and move ont the next account when an API limit is reached.  It will also respect the 5 minute rule that the incremental APIs have.

##Configuration
Clone the repo
```git clone https://github.com/Skeyelab/Zendesk-Incremental-Tickets.git```

```cd Zendesk-Incremental-Tickets```

Install gems
```bundle install```

Setup "desks" table:

```sql
CREATE TABLE `desks` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `domain` varchar(128) DEFAULT NULL,
  `user` varchar(128) DEFAULT NULL,
  `token` varchar(128) DEFAULT NULL,
  `last_timestamp` int(11) DEFAULT '0',
  `last_timestamp_event` int(11) DEFAULT '0',
  `wait_till` int(11) DEFAULT '0',
  `wait_till_event` int(11) DEFAULT '0',
  `active` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `domain` (`domain`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=latin1;
```
Add Zendesk accounts.  If you only have one, that is fine. You need to populate `domain`, `user` and `token`.  Set `active` = 1 to collect data from this account.

##.env
You will need to rename .env.example and edit it with your database settings.



##inctix.rb
```bash
chmod +x inxtix.rb
```
This should be run as a service.  I prefer to use supervisord, but you are free to use what ever you prefer to daemonize a process.  Configuring this is beyond the scope of this document.

