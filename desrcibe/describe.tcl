set val(chan)   Channel/WirelessChannel    ;# channel type
set val(prop)   Propagation/TwoRayGround   ;# radio-propagation model
set val(netif)  Phy/WirelessPhy            ;# network interface type
set val(mac)    Mac/802_11                 ;# MAC type
set val(ifq)    CMUPriQueue     ;# interface queue type
set val(ll)     LL                         ;# link layer type
set val(ant)    Antenna/OmniAntenna        ;# antenna model
set val(ifqlen) 100                         ;# max packet in ifq
set val(nn)     100                         ;# number of mobilenodes
set val(rp)     DSR                      ;# routing protocol
set val(x)      1000                      ;# X dimension of topography
set val(y)      1000                      ;# Y dimension of topography
set val(stop)   200.0                        ;# time of simulation end
set val(energymodel)    EnergyModel     ;
set val(initialenergy) 100
set round 		1
set MESSAGE_PORT 42 
set ns [new Simulator]
set dist 0
set len 0
set mhk 0
#Setup topography object
set topo       [new Topography]
$topo load_flatgrid $val(x) $val(y)
create-god $val(nn)

#Open the NS trace file
set f [open setup.txt w]
set f1 [open clusterheads.txt w]
set f2 [open steady.txt w]
set f3 [open data_info.txt w]
set f4 [open fairness.txt w]
set tracefile [open simple.tr w]
$ns trace-all $tracefile
		
#Open the NAM trace file
set nf [open simple.nam w]
$ns namtrace-all $nf
$ns namtrace-all-wireless $nf $val(x) $val(y)
set chan [new $val(chan)];#Create wireless channel

#===================================
#     Mobile node parameter setup
#===================================
$ns node-config -adhocRouting  $val(rp) \
                -llType        $val(ll) \
                -macType       $val(mac) \
                -ifqType       $val(ifq) \
                -ifqLen        $val(ifqlen) \
                -antType       $val(ant) \
                -propType      $val(prop) \
                -phyType       $val(netif) \
                -channel       $chan \
                -topoInstance  $topo \
				-energyModel $val(energymodel) \
				-idlePower 0.0 \
				-rxPower 1.0 \
				-txPower 1.0 \
	          	-sleepPower 0.001 \
    	      	-transitionPower 0.2 \
    	      	-transitionTime 0.005 \
				-initialEnergy $val(initialenergy) \
                -agentTrace    ON \
                -routerTrace   ON \
                -macTrace      ON \
                -movementTrace ON
set n_(0) [$ns node]
$n_(0) set X_ 500
$n_(0) set Y_ 500
$n_(0) set Z_ 0.0
$ns initial_node_pos $n_(0) 20
$n_(0) color blue
$ns at 0.0 "$n_(0) color blue"

for {set i 1} {$i < $val(nn)} {incr i} {
	set n_($i) [$ns node]
	$n_($i) set X_ [expr rand()*[expr 0.8*$val(x)] +[expr 0.1*$val(x)]]
	$n_($i) set Y_ [expr rand()*[expr 0.8*$val(y)] +[expr 0.1*$val(y)]]
	$ns initial_node_pos $n_($i) 20
}


for {set i 0} {$i <$val(nn)} { incr i} {
	set l_($i) [new LL]
	$ns attach-agent $n_($i) $l_($i)
	$l_($i) set macDA_ [expr $i+100]
}
	
for {set i 0} {$i <$val(nn)} {incr i} {
	set Dagent_($i) [new Agent/DSRAgent]
	$ns attach-agent $n_($i) $Dagent_($i)

}

for {set i 0} {$i <$val(nn)} { incr i} {
	dict set initialpos($i) loc [$n_($i) set X_] [$n_($i) set Y_]
	 
}

# setting Final Destinations of each node
for {set j 0} {$j < [expr $val(stop)]} {incr j} {
	for {set i 1} {$i < 41} { incr i} {
		set time 5.0
		set x [expr 100*cos(rand()*360 * 22.0 /(7.0 *180))]
		set y [expr 100*sin(rand()*360 * 22.0 /(7.0 *180))]
		set cx [lindex [dict get $initialpos($i) loc] 0]
		set cy [lindex [dict get $initialpos($i) loc] 1] 
		$ns at  [expr $j*$time] "$n_($i) setdest [expr $x+$cx] [expr $y+$cy] 2.0"
	}
}

for {set i 0} {$i < $val(nn)} {incr  i} {
	set p_($i) [new Agent/Ping]
	$ns attach-agent $n_($i) $p_($i)
#	puts "n_($i)  [$n_($i) id]  [$p_($i) agent_addr_]"
}


for {set i 0} {$i <$val(nn)} {incr i} {
	for {set j $i} {$j <$val(nn)} {incr j} {
		if {$j != $i} {
			$ns connect $p_($i) $p_($j)
		}
	}
}

set nodelistt { }
set clusterheadtable {}
array set distance {}
set mycluster {}
array set counter {}
array set cluster_list {}
set count 0
array set datalist_ {}



proc sortDictByValue {dict args} {
        set lst {}
        dict for {k v} $dict {lappend lst [list $k $v]}
        return [concat {*}[lsort -index 1 {*}$args $lst]]	
   }

proc chooseclusterheadrandom {} {
	global clusterheadtable ns n_ val xlocs ylocs node_list_BS f f1 dist len ids mhk clusterhead mycluster counter cluster_list count a_
	set clusterheadtable {0 0 0 0 0 0}
	set value {0 0 0 0 0}
for {set i 1} {$i < $val(nn)} {incr i} {
	set x [$n_($i) set X_]
	set y [$n_($i) set Y_]
	set dist [expr sqrt((pow(500-$x,2)) + (pow(500-$y,2)))]
	dict set distance $i dist_to_bs $dist 
	dict set distance $i node $i
	}

     set sorted [sortDictByValue $distance]
	
     dict for {id info} $sorted {
     dict with info {
      puts $f1 "$id:$info"

    }
    }
	

	for {set i 0} {$i < 11} {incr i} {
	set mhk [lindex $sorted $i 3]
	lset clusterheadtable [expr $i/2] $mhk
	}
	
	 puts $f1 "CLUSTERHEADTABLE:$clusterheadtable"
	
	for {set i 0} {$i < 5} {incr i} {
		set ind [lindex $clusterheadtable $i]
		$n_($ind) color red
		$ns at [$ns now] "$n_($ind) color red"
		dict set node_list_BS($ind) node_list {}
	}
	for {set i 0} {$i<5} {incr i} {
		set nn [lindex $clusterheadtable $i]
		
		set addr [$n_($nn) node-addr]
		set locx [$n_($nn) set X_]
		set locy [$n_($nn) set Y_]
		set energ [$n_($nn) energy]
		#puts $f1 "ROHIT:$ns at [$ns now] $a_($nn) send_message 900 1 [$n_(10) set address_] 42"
		for {set j 1} {$j < $val(nn)} {incr j} {
		
		puts $f "TESTING:$ns at [$ns now]  $nn send_message to $j hello $locx $locy $energ"

		}
	}

	array set flag {}
	for {set i 1} {$i < $val(nn)} {incr i} {
		#puts "sending ack $i"
		#set addr [$n_($i) node-addr]
		#set locx [$n_($i) set X_]
		#set locy [$n_($i) set Y_]
		#set energ [$n_($i) energy]
		set flag($i) 1		
		for {set j 0} { $j < 5} { incr j} {
			set nn [lindex $clusterheadtable $j]
			if {$nn == $i} {
				set flag($i) 0
				break			
			}
		
		}
}
	

set counter(0) 0
set c_c 0
for {set j 0} {$j < 5} {incr j} {
		
		set rht 0
		set locCHx [$n_([lindex $clusterheadtable $j]) set X_]
		set locCHy [$n_([lindex $clusterheadtable $j]) set Y_]
		for {set i 1} {$i < $val(nn)} {incr i} {
		set locx [$n_($i) set X_]
		set locy [$n_($i) set Y_]
		set dist_CH [expr sqrt((pow($locCHx-$locx,2)) + (pow($locCHy-$locy,2)))]
		if { $flag($i) == 1 && $dist_CH < 300} {
		set flag($i) 0
		set rht [expr $rht + 1]
		puts $f "ROHIT:$ns at [expr [$ns now]] send_message to CH [lindex $clusterheadtable $j] {ack $locx $locy $i} "
		set count [expr $count + 1]
		lappend mycluster $i
		}
		}
		
#puts $f1 "MEHAK: $mycluster"
#puts $f1 "COUNT: $count"
		
		
		set c_c [expr $c_c + 1]
		set decr [expr $c_c - 1]
		set counter($c_c) [expr $counter($decr) + $rht]
		}
		for {set i 0} {$i < 5} {incr i} {
		puts $f "COUNTER: $counter($i)"
	}
	
   }
chooseclusterheadrandom




proc send_data_to_BS {} {
global val datalist_ n_ f3
for {set i 0} {$i  < $val(nn)} {incr i} {
	#if {[expr rand()] > 0.5} {
	set datalist_($i) [expr rand()]
	#} else {
	#set  datalist_($i) 0
	#}
}

} 
puts $f3 "MEHAK:"




proc send_slot {} {
	global val  a_ n_ ns clusterinfo_ clusterheadtable mycluster counter f1 count f2
	
	set remaining 1
	#puts $f1 "Rohit:$mycluster"
	#puts $f1 "MEHAK"
	for {set i 0} {$i < 5} {incr i} {
	set start 0
		set nn [lindex $clusterheadtable $i]
		if {$i < 4} {
		for {set j $counter($i)} {$j < $counter($remaining)} {incr j} {
			set id_of_node [lindex $mycluster $j]
			puts $f2 "$ns at [expr [$ns now]] $nn sending_slot_schedule {$id_of_node node slot $start } "
			set start [expr $start + 1]
		}
			set remaining [expr $remaining + 1]
		}
			if {$i == 4} {
			set remaining $count
		for {set j $counter($i)} {$j < $remaining} {incr j} {
			#puts $f1 "Rohit:$mycluster"
			set id_of_node [lindex $mycluster $j]
			puts $f2 "$ns at [expr [$ns now]] $nn sending_slot_schedule {$id_of_node node slot $start } "
			set start [expr $start + 1]
		}
			}

	   }
}


proc steadystatephase {} {
	global clusterheadtable clusterinfo_ ns n_ a_ val recv_node_CH_info_ MESSAGE_PORT counter mycluster f2 count f3 datalist_
	set remaining 1
	send_slot
	for {set i 0} {$i<5} {incr i} {
		set nn [lindex $clusterheadtable $i]
		set addr [$n_($nn) node-addr]
		set locx [$n_($nn) set X_]
		set locy [$n_($nn) set Y_]
		set energ [$n_($nn) energy]
		set start 0
		if {$i < 4} {
		for {set j $counter($i)} {$j < $counter($remaining)} {incr j} {
			set id_of_node [lindex $mycluster $j]
			puts $f2 "$ns at [expr [$ns now]] $nn send_message to $id_of_node {data_req_msg $locx $locy $energ $addr} "
			set start [expr $start + 1]
		}
			set remaining [expr $remaining + 1]
		}
			if {$i == 4} {
			set remaining $count
		for {set j $counter($i)} {$j < $remaining} {incr j} {
			#puts $f1 "Rohit:$mycluster"
			set id_of_node [lindex $mycluster $j]
			puts $f2 "$ns at [expr [$ns now]] $nn send_message 900 $id_of_node {data_req_msg $locx $locy $energ $addr} "
			set start [expr $start + 1]
		}
			}
		
		
	}	
	send_data_to_BS

	foreach index [array names datalist_] {
        puts $f3 "$datalist_($index)"
}
}
steadystatephase
proc finish {} {
        global ns tracefile f nf f1 f4
        $ns flush-trace
        close $f
        close $nf
		close $f1
		close $f4
        puts "running nam..."
        exec nam simple.nam &
        exit 0
}
#finish
#$ns at $val(stop) 
#$ns run



