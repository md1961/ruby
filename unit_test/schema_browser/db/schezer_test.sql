
--
-- Table structure for table `reserve_header_trash`
--

DROP TABLE IF EXISTS `reserve_header_trash`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `reserve_header_trash` (
  `reserve_id` int(10) unsigned NOT NULL auto_increment,
  `reservoir_id` int(10) unsigned NOT NULL default '0',
  `date_reserve` date NOT NULL default '0000-00-00' COMMENT '鉱量の日付',
  `possibility` int(10) unsigned NOT NULL default '0' COMMENT '実現確率',
  `date_rsv_input` datetime default NULL COMMENT '入力した日時',
  `username_input` varchar(20) default NULL COMMENT '入力したユーザー名',
  `method_reserve` varchar(10) default NULL,
  `summary` text,
  `date_trashed` datetime NOT NULL default '0000-00-00 00:00:00' COMMENT '廃棄した日付',
  PRIMARY KEY  (`reserve_id`),
  UNIQUE KEY `reserve_id` (`reserve_id`),
  UNIQUE KEY `reservoir_id` (`reservoir_id`,`date_reserve`,`possibility`,`date_rsv_input`),
  CONSTRAINT `reserve_header_trash_ibfk_1` FOREIGN KEY (`reservoir_id`) REFERENCES `reservoir` (`reservoir_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COMMENT='reserve_header テーブルからの廃棄レコード';
SET character_set_client = @saved_cs_client;


DROP VIEW IF EXISTS `unit_with_base`;
CREATE VIEW `unit_with_base` AS
  SELECT
      `unit_id`
    , `unit`
    , `unit_zen`
    , `base_unit`
    , `unit_order`
  FROM `unit` u, `base_unit` bu
  WHERE u.`base_unit_id` = bu.`base_unit_id`;

