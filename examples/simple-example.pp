node 'rsnapshot.example.com' {			# an rsnapshot server

	# NOTE: with the architecture of this puppet module, multiple,
	# independent rsnapshot instances can run at the same time. this is
	# very useful if you want the backup server to concurrently run
	# multiple backups with rsnapshot.

	# NOTE: the below examples are contrived, choose your own param values!

	$base = '/mnt/backups/rsnapshot/',	# storage destination

	class { '::rsnapshot':
		# HACK: fixes a broken rsnapshot from RPMForge on request...
		bugfix_includeconf => true,
	}

	#
	#	backup foo1
	#
	rsnapshot::config { 'foo1':
		snapshots => "${base}foo1/",	# snapshot root
		frequency => 'daily',		# hourly,daily,weekly,monthly
		include => [],
		exclude => [],
		retain_hourly => 6,
		retain_daily => 7,
		retain_weekly => 4,
		retain_monthly => 12,
		cron => true,
		ensure => present,
	}

	rsnapshot::backup { 'foo1-data':
		config => 'foo1',
		source => 'root@foo1.example.com:/export/data/',
		# NOTE: add --sparse as an example rsync argument...
		options => ['+rsync_long_args=--hard-links --sparse'],
		ensure => present,
	}

	rsnapshot::backup { 'foo1-root':
		config => 'foo1',
		source => 'root@foo1.example.com:/root/',
		options => [],
		ensure => present,
	}

	rsnapshot::backup { 'foo1-etc':
		config => 'foo1',
		source => 'root@foo1.example.com:/etc/',
		options => [],
		ensure => present,
	}

	rsnapshot::backup { 'foo1-log':
		config => 'foo1',
		source => 'root@foo1.example.com:/var/log/',
		options => [],
		ensure => present,
	}

	#
	#	backup bar1
	#
	rsnapshot::config { 'bar1':
		snapshots => "${base}bar1/",	# snapshot root
		frequency => 'daily',		# hourly,daily,weekly,monthly
		include => [],
		exclude => [],
		retain_hourly => 6,
		retain_daily => 7,
		retain_weekly => 4,
		retain_monthly => 12,
		cron => true,
		ensure => present,
	}

	rsnapshot::backup { 'bar1-root':
		config => 'bar1',
		source => 'root@bar1.example.com:/root/',
		options => [],
		ensure => present,
	}

	rsnapshot::backup { 'bar1-etc':
		config => 'bar1',
		source => 'root@bar1.example.com:/etc/',
		options => [],
		ensure => present,
	}

	rsnapshot::backup { 'bar1-mail':
		config => 'bar1',
		source => 'root@bar1.example.com:/var/mail/',
		options => [],
		ensure => present,
	}
}

