# Rsnapshot puppet module
# Copyright (C) 2012-2013  James Shubin
# Written by James Shubin <james@shubin.ca>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# NOTE: this module is designed to use rsnapshot with the sync_first option on.

# TODO: we could probably run: "rsnapshot configtest" somewhere
# FIXME: this module *should* eventually function properly with ensure => absent, but doesn't right now

class rsnapshot::vardir {	# module vardir snippet
	if "${::puppet_vardirtmp}" == '' {
		if "${::puppet_vardir}" == '' {
			# here, we require that the puppetlabs fact exist!
			fail('Fact: $puppet_vardir is missing!')
		}
		$tmp = sprintf("%s/tmp/", regsubst($::puppet_vardir, '\/$', ''))
		# base directory where puppet modules can work and namespace in
		file { "${tmp}":
			ensure => directory,	# make sure this is a directory
			recurse => false,	# don't recurse into directory
			purge => true,		# purge all unmanaged files
			force => true,		# also purge subdirs and links
			owner => root,
			group => nobody,
			mode => 600,
			backup => false,	# don't backup to filebucket
			#before => File["${module_vardir}"],	# redundant
			#require => Package['puppet'],	# no puppet module seen
		}
	} else {
		$tmp = sprintf("%s/", regsubst($::puppet_vardirtmp, '\/$', ''))
	}
	$module_vardir = sprintf("%s/rsnapshot/", regsubst($tmp, '\/$', ''))
	file { "${module_vardir}":		# /var/lib/puppet/tmp/rsnapshot/
		ensure => directory,		# make sure this is a directory
		recurse => true,		# recursively manage directory
		purge => true,			# purge all unmanaged files
		force => true,			# also purge subdirs and links
		owner => root, group => nobody, mode => 600, backup => false,
		require => File["${tmp}"],	# File['/var/lib/puppet/tmp/']
	}
}

class rsnapshot(
	$bugfix_includeconf = false,
	$ensure = present
) {
	include rsnapshot::vardir
	#$vardir = $::rsnapshot::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::rsnapshot::vardir::module_vardir, '\/$', '')

	$bool_ensure = $ensure ? {
		absent => false,
		default => true,
	}

	$valid_ensure = $bool_ensure ? {
		false => absent,
		default => present,
	}

	package { 'rsnapshot':			# NOTE: centos needs rpmforge
		ensure => $valid_ensure,
	}

	if $bugfix_includeconf {
		file { "${vardir}/rsnapshot.fixed":
			owner => root,
			group => root,
			mode => 755,	# u=rw,go=r
			source => 'puppet:///modules/rsnapshot/rsnapshot.fixed',
			require => File["${vardir}/"],
		}
		$bad_line = '	if($config_file =~ /^`.*`$/) {'	# search for bug
		exec { '/bin/cp -a /var/lib/puppet/tmp/rsnapshot/rsnapshot.fixed /usr/bin/rsnapshot':
			onlyif => "/bin/grep -qFx '${bad_line}' '/usr/bin/rsnapshot'",
			require => [File["${vardir}/rsnapshot.fixed"], Package['rsnapshot']],
		}
	}

	# set the main rsnapshot file to something special
	file { '/etc/rsnapshot.conf':
		ensure => $valid_ensure,
		content => "# This software is being managed by puppet.\n",
		require => Package['rsnapshot'],
	}

	file { '/var/log/rsnapshot/':
		ensure => directory,		# make sure this is a directory
		recurse => false,		# don't delete logs automatically
		purge => false,
		force => false,
		owner => root, group => root, mode => 644,
		require => Package['rsnapshot'],
	}

	# build a special namespace to allow for simultaneous rsnapshot
	file { '/etc/rsnapshot/':
		ensure => directory,		# make sure this is a directory
		recurse => true,		# recursively manage directory
		purge => true,
		force => true,
		owner => root, group => root, mode => 644,
		require => Package['rsnapshot'],
	}

	file { '/var/run/rsnapshot/':
		ensure => directory,		# make sure this is a directory
		recurse => false,		# don't delete files here!
		purge => false,
		force => false,
		owner => root, group => root, mode => 644,
		backup => false,
		require => Package['rsnapshot'],
	}
}

# TODO: we could probably add a yearly option too!
# Each rsnapshot that we want to run concurrently gets it's own config.
# You can specify a frequency of how often you want rsnapshot to run.
# You may also specify a "retain" count for each frequency.
define rsnapshot::config(
	$snapshots,		# the snapshot root
	$frequency = 'daily',	# choose: 'hourly', 'daily', 'weekly' 'monthly'
	$include = [],
	$exclude = [],
	$retain_hourly = 6,
	$retain_daily = 7,
	$retain_weekly = 4,
	$retain_monthly = 3,
	$default_rsync_short_args = ['-a'],
	$default_rsync_long_args = ['--delete', '--numeric-ids', '--relative', '--delete-excluded'],
	$rsync_short_args = [],
	$rsync_long_args = [],
	$cron = true,		# lets us turn off cron, but keep configs on
	$ensure = present
) {
	include 'rsnapshot'

	$bool_ensure = $ensure ? {
		absent => false,
		default => true,
	}

	$valid_ensure = $bool_ensure ? {
		false => absent,
		default => present,
	}

	$cron_ensure = $bool_ensure ? {
		false => absent,
		default => $cron ? {
			false => absent,
			default => present,
		},
	}

	if $bool_ensure {
		file { "/var/log/rsnapshot/rsnapshot-${name}/":
			ensure => directory,		# make sure this is a directory
			recurse => false,		# don't delete logs automatically
			purge => false,
			force => false,
			owner => root, group => root, mode => 644,
			require => File['/var/log/rsnapshot/'],
		}

		file { "/etc/rsnapshot/rsnapshot-${name}/":
			ensure => directory,		# make sure this is a directory
			recurse => true,		# recursively manage directory
			purge => true,
			force => true,
			owner => root, group => root, mode => 644,
			require => File['/etc/rsnapshot/'],
		}

		file { "/etc/rsnapshot/rsnapshot-${name}/rsnapshot.d/":
			ensure => directory,		# make sure this is a directory
			recurse => true,		# recursively manage directory
			purge => true,
			force => true,
			owner => root, group => root, mode => 644,
			require => File["/etc/rsnapshot/rsnapshot-${name}/"],
		}

		file { "/etc/rsnapshot/rsnapshot-${name}/include.sh":
			content => template('rsnapshot/include.sh.erb'),
			owner => root,
			group => root,
			mode => 755,		# u=rwx,go=rx
			ensure => present,
			require => File["/etc/rsnapshot/rsnapshot-${name}/"],
		}

		file { "/etc/rsnapshot/rsnapshot-${name}/rsnapshot.conf":
			content => template('rsnapshot/rsnapshot.conf.erb'),
			owner => root,
			group => root,
			mode => 644,
			ensure => present,
			require => [
				File["/var/log/rsnapshot/rsnapshot-${name}/"],
				File["/etc/rsnapshot/rsnapshot-${name}/rsnapshot.d/"],
				File["/etc/rsnapshot/rsnapshot-${name}/include.sh"],
				File['/var/run/rsnapshot/'],
			],
		}
	}

	# From the rsnapshot manual: It is usually a good idea to schedule the
	# larger backup levels to run a bit before the lower ones. For example,
	# in the crontab above, notice that "daily" runs 10 minutes before
	# "hourly". The main reason for this is that the daily rotate will pull
	# out the oldest hourly and make that the youngest daily (which means
	# that the next hourly rotate will not need to delete the oldest
	# hourly), which is more efficient. A secondary reason is that it is
	# harder to predict how long the lowest backup level will take, since
	# it needs to actually do an rsync of the source as well as the rotate
	# that all backups do.

	# Example of job definition:
	# .---------------- minute (0 - 59)
	# |  .------------- hour (0 - 23)
	# |  |  .---------- day of month (1 - 31)
	# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
	# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
	# |  |  |  |  |
	# *  *  *  *  * user-name  command to be executed
	$sync_command = "/usr/bin/rsnapshot -c /etc/rsnapshot/rsnapshot-${name}/rsnapshot.conf sync && "

	# we only need the hourly cron when doing this frequency
	if $frequency == 'hourly' {
		$cron_hourly = $frequency ? {
			'hourly' => "${sync_command}",
			default => '',
		}

		# run every four hours
		# 0 */4 *  *  *	root  rsnapshot hourly
		cron { "rsnapshot-hourly-${name}":
			ensure => $cron_ensure,
			minute => '0',
			hour => '*/4',
			#monthday => '*',
			#month => '*',
			#weekday => '*',
			user => root,
			command => "${cron_hourly}/usr/bin/rsnapshot -c /etc/rsnapshot/rsnapshot-${name}/rsnapshot.conf hourly",
		}
	}

	if ($frequency == 'hourly') or ($frequency == 'daily') {
		$cron_daily = $frequency ? {
			'daily' => "${sync_command}",
			default => '',
		}

		# run at 23:50 every day
		# 50 23 *  *  *	root  rsnapshot daily
		cron { "rsnapshot-daily-${name}":
			ensure => $cron_ensure,
			minute => '50',
			hour => '23',
			#monthday => '*',
			#month => '*',
			#weekday => '*',
			user => root,
			command => "${cron_daily}/usr/bin/rsnapshot -c /etc/rsnapshot/rsnapshot-${name}/rsnapshot.conf daily",
		}
	}

	if ($frequency == 'hourly') or ($frequency == 'daily') or ($frequency == 'weekly') {
		$cron_weekly = $frequency ? {
			'weekly' => "${sync_command}",
			default => '',
		}

		# run at 23:40 every saturday
		# 40 23 *  *  6	root  rsnapshot weekly
		cron { "rsnapshot-weekly-${name}":
			ensure => $cron_ensure,
			minute => '40',
			hour => '23',
			#monthday => '*',
			#month => '*',
			weekday => '6',
			user => root,
			command => "${cron_weekly}/usr/bin/rsnapshot -c /etc/rsnapshot/rsnapshot-${name}/rsnapshot.conf weekly",
		}
	}

	if ($frequency == 'hourly') or ($frequency == 'daily') or ($frequency == 'weekly') or ($frequency == 'monthly' ) {
		$cron_monthly = $frequency ? {
			'monthly' => "${sync_command}",
			default => '',
		}

		# run at 23:30 on the first of every month
		# 30 23 1  *  *	root  rsnapshot monthly
		cron { "rsnapshot-monthly-${name}":
			ensure => $cron_ensure,
			minute => '30',
			hour => '23',
			monthday => '1',
			#month => '*',
			#weekday => '*',
			user => root,
			command => "${cron_monthly}/usr/bin/rsnapshot -c /etc/rsnapshot/rsnapshot-${name}/rsnapshot.conf monthly",
		}
	}
}

# TODO: we could add an order parameter here to decide which order each backup or backupscript gets run in...
define rsnapshot::backup(
	$config,		# which parent config define does this use ?
	$source,		# source to backup, eg: root@example.com:/home/ or /usr/local/ or /etc/passwd
	$options = [],
	$comment = '',
	$ensure = present
) {
	$bool_ensure = $ensure ? {
		absent => false,
		default => true,
	}

	$valid_ensure = $bool_ensure ? {
		false => absent,
		default => present,
	}

	if $bool_ensure {
		Rsnapshot::Config[$config] -> Rsnapshot::Backup[$name]
	}

	file { "/etc/rsnapshot/rsnapshot-${config}/rsnapshot.d/rsnapshot-${name}.backup.conf":
		content => template('rsnapshot/rsnapshot.backup.conf.erb'),
		owner => root,
		group => root,
		mode => 644,
		ensure => $valid_ensure,
		require => $bool_ensure ? {
			true => File["/etc/rsnapshot/rsnapshot-${config}/rsnapshot.d/"],
			default => undef,
		},

	}
}

# TODO
#define rsnapshot::backupscript(
#	$config,
#	$script,
#	$comment = ''
#) {
#	Rsnapshot::Config[$config] -> Rsnapshot::Backupscript[$name]
#}

