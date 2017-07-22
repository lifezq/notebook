#!/bin/bash
yum install -y ceph 
#vim /etc/ceph/ceph.conf
#[global]
#fsid = ce01a375-7ab8-4f1a-bcef-5883a6288033
#
#mon host = 127.0.0.1
#mon initial members = Ryan
#
#mon_allow_pool_delete = 1
#
#public network = 127.0.0.1/8
#auth cluster required = cephx
#auth service required = cephx
#auth client  required = cephx
#
#osd journal size = 4096
#osd poll default size = 2
#osd pool default min size = 1
#osd pool default pg num = 128
#osd pool default pgp num = 128
#osd crush chooseleaf type = 1
#
#osd max object name len = 256 
#osd max object namespace len = 64
#
#[mgr]
#mgr_modules = dashboard

#ceph-authtool --help
ceph-authtool -C /etc/ceph/ceph.mon.Ryan.keyring -n mon.Ryan --cap mon 'allow *' --cap osd 'allow profile osd' --gen-key
ceph-authtool -C /etc/ceph/ceph.client.admin.keyring --gen-key --cap mon 'allow *' --cap osd 'allow *'
ceph-authtool /etc/ceph/ceph.mon.Ryan.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
monmaptool --create --add Ryan 127.0.0.1  --fsid ce01a375-7ab8-4f1a-bcef-5883a6288033 /etc/ceph/monmap
mkdir /var/lib/ceph/mon/ceph-Ryan
ceph-mon -i Ryan --mkfs --monmap /etc/ceph/monmap --keyring /etc/ceph/ceph.mon.Ryan.keyring
ceph-mon -i Ryan
ceph -s
#ceph-mon -i Ryan --inject-monmap /etc/ceph/monmap
ceph osd create
mkdir /var/lib/ceph/osd/ceph-0
ceph-osd -i 0 --mkfs --mkkey --osd-uuid 6715682d-e8b1-4b91-a45f-9240025b516c
ceph auth add osd.0 mon 'allow profile osd' osd 'allow *' -i /var/lib/ceph/osd/ceph-0/keyring
ceph -s
#ceph osd crush --help
ceph osd crush dump
ceph osd crush add-bucket Ryan0 host
ceph osd crush move Ryan0 root=default
ceph auth import -i /etc/ceph/ceph.client.admin.keyring
ceph-osd -i 0
ceph -s
ceph osd crush move osd.0 host=Ryan0
ceph osd crush add osd.0 0.4 host=Ryan0
#ceph auth list
#vim /etc/ceph/ceph.conf
killall ceph-mon
ceph-mon -i Ryan
#ceph-osd -i 0
ceph osd create 1f0379b7-9f91-48ad-b041-886b7f50d9d0
mkdir /var/lib/ceph/osd/ceph-1
ceph-osd -i 1 --mkfs --mkkey --osd-uuid 1f0379b7-9f91-48ad-b041-886b7f50d9d0
#ceph auth add --help
ceph auth add osd.1 mon 'allow profile osd' osd 'allow *' -i /var/lib/ceph/osd/ceph-1/keyring
#ceph auth list
#ceph osd dump
ceph osd crush add-bucket Ryan1 host
ceph osd crush move Ryan1 root=default
ceph osd crush add osd.1 0.4 host=Ryan1
ceph-osd -i 1
ceph osd create 78d9d7f4-f41d-44f5-a24c-b29d001133d2
mkdir /var/lib/ceph/osd/ceph-2
ceph-osd -i 2 --mkfs --mkkey --osd-uuid 78d9d7f4-f41d-44f5-a24c-b29d001133d2
ceph auth add osd.2 mon 'allow profile osd' osd 'allow *' -i /var/lib/ceph/osd/ceph-2/keyring
ceph osd crush add-bucket Ryan2 host
ceph osd crush move Ryan2 root=default
ceph osd crush add osd.2 0.4 host=Ryan2
ceph-osd -i 2
#ceph auth list
ceph osd create b347b2cb-f493-429d-88cd-ab5234069b44
mkdir /var/lib/ceph/osd/ceph-3
ceph-osd -i 3 --mkfs --mkkey --osd-uuid b347b2cb-f493-429d-88cd-ab5234069b44
ceph auth add osd.3 mon 'allow profile osd' osd 'allow *' -i /var/lib/ceph/osd/ceph-3/keyring
ceph osd crush add-bucket Ryan3 host
ceph osd crush move Ryan3 root=default
ceph osd crush add osd.3 0.4 host=Ryan3
#ceph osd crush dump
ceph-osd -i 3
ceph osd crush rm osd.3
ceph osd crush rm osd.2
ceph osd crush rm osd.1
ceph osd crush rm osd.0
ceph osd crush add osd.3 0.4 host=Ryan3
ceph osd crush add osd.2 0.4 host=Ryan2
ceph osd crush add osd.1 0.4 host=Ryan1
ceph osd crush add osd.0 0.4 host=Ryan0
#ceph auth list
ceph osd getcrushmap -o /etc/ceph/crushmap
#ceph-mon -i Ryan --extract-monmap -o  /etc/ceph/monmap
#ceph mon --help
ceph osd pool rename rbd hotdb
#ceph osd dump
ceph osd pool set hotdb pg_num 128
ceph osd pool set hotdb pgp_num 128
#ceph osd pool --help
ceph osd pool create ecpool 128 128 erasure 
#ceph -s
#ceph osd tier --help
ceph osd tier add-cache hotdb ecpool
ceph osd tier add hotdb ecpool
ceph osd tier add ecpool hotdb
ceph osd tier add-cache ecpool hotdb 128
ceph osd tier cache-mode writeback
ceph osd tier cache-mode hotdb writeback
ceph osd tier set-overlay hotdb ecpool
ceph osd tier set-overlay ecpool hotdb

ceph osd pool set hotdb target_max_bytes 1000000000000
ceph osd pool set hotdb hit_set_count 128
ceph osd pool set hotdb hit_set_period 3600
#ceph osd pool --help | grep bloom
#ceph osd --help | grep bloom
ceph osd pool set hotdb hit_set_  
ceph osd pool set hotdb hit_set_type bloom
ceph osd pool set hotdb min_read_recency_for_promote 5
ceph osd pool set hotdb min_write_recency_for_promote 5
ceph osd pool set hotdb target_max_objects 50
ceph osd pool set hotdb cache_target_dirty_ratio 0.4
ceph osd pool set hotdb  cache_target_dirty_high_ratio 0.6
ceph osd pool set hotdb cache_target_full_ratio 0.6
ceph osd pool set hotdb cache_min_flush_age 300
ceph osd pool set hotdb cache_min_evict_age 600
ceph osd pool set hotdb target_max_objects 128
