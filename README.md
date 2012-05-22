rsync-cron-wrapper
==================

A simple tool that allows you to run rsync through cron.

This tool will create a pid file and verify that your rsync command does not have multiple instances running causing resource contention. This will allow you to put a cronjob that starts an rsync process every 5 minutes no matter how large your directory.

Please report any bugs and any feature suggestions
