
--
-- Table structure for table `user`
--

DROP TABLE IF EXISTS `user`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `user` (
  `user_id` int(10) unsigned NOT NULL auto_increment,
  `username` varchar(40) NOT NULL,
  `password` varchar(80) default NULL,
  `time_limit` datetime default NULL,
  PRIMARY KEY  (`user_id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=1250 DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `user`
--

LOCK TABLES `user` WRITE;
/*!40000 ALTER TABLE `user` DISABLE KEYS */;
INSERT INTO `user` VALUES
	  (457, 'nagaoka' , NULL, NULL)
	, (458, 'hokkaido', NULL, NULL)
	, (459, 'akita'   , NULL, NULL)
	, (460, 'jpo'     , NULL, NULL)
	, (462, 'readonly', NULL, NULL)
	, (541, 'none'    , NULL, NULL)
	, (830, 'guest'   , NULL, NULL)
	;
/*!40000 ALTER TABLE `user` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `reserve_header`
--

LOCK TABLES `reserve_header` WRITE;
/*!40000 ALTER TABLE `reserve_header` DISABLE KEYS */;
INSERT INTO `reserve_header` VALUES
	  (3, 1, '2002-12-31', 90, 0, '2001-03-01 00:00:00', NULL, 'S', ' 減退見直し')
	;
/*!40000 ALTER TABLE `reserve_header` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `reserve`
--

LOCK TABLES `reserve` WRITE;
/*!40000 ALTER TABLE `reserve` DISABLE KEYS */;
INSERT INTO `reserve` VALUES
	  (5, 3, 1, '6543.21', 1)
	, (6, 3, 2, '8765.43', 2)
	;
/*!40000 ALTER TABLE `reserve` ENABLE KEYS */;
UNLOCK TABLES;

