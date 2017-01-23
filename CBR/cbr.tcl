#===================================
#     Simulation parameters setup
#===================================
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
#if { $val(rp) == "DSR" } {
#	set val(ifq) CMUPriQueue 
#	} else {
#	set val(ifq) Queue/DropTail/PriQueue
#	}
#===================================
#        Initialization        
#===================================
#Create a ns simulator
set ns [new Simulator]

#Setup topography object
set topo       [new Topography]
$topo load_flatgrid $val(x) $val(y)
create-god $val(nn)

#Open the NS trace file
set f [open record.txt w]
set f1 [open packets.txt w]
set f2 [open energy_record.txt w]
set f3 [open packet_record.txt w]
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

#===================================
#        Nodes Definition        
#===================================

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



array set initialpos {}
set clusterheadtable {}
array set clusterinfo_ {}

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

# random cluster head selection
proc myRand { l } {
    global clusterheadtable val n_ f1
    puts $f1 "L==$l"
    set maxFactor [expr [expr $max + 1] - $min]
    
    set min $l
    for {set i 1} {$i < $val(nn)} { incr i} {
    	set x [$n_($i) set X_]
    	set y [$n_($i) set Y_]
    	set d [expr sqrt((pow(500-$x,2)) + (pow(500-$y,2)))]
    	if { $d < $min} {
    		set value $i
    	}
    set value [expr int([expr rand() * 100])]
    set value [expr [expr $value % $maxFactor] + $min]
    for {set i 0} {$i < [llength $clusterheadtable]} {incr i} {
	if {$value == [lindex $clusterheadtable $i]} {
		set value [myRand $l]
		puts $f1 "$value   rand"
		break;
	}
    }
    }
    return $value
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

# cluster head and clustering of nodes in the network
set xlocs { 270 725 775 500 220 }
set ylocs { 250 250 600 750 600 }
set nodelistt { }
proc chooseclusterheadrandom {} {
	global clusterheadtable ns n_ val xlocs ylocs node_list_BS f1
	set clusterheadtable { }	
	set min {1000 1000 1000 1000 1000}
	set value {0 0 0 0 0 }
	set max 0
    for {set i 1} {$i < $val(nn)} { incr i} {
    	set x [$n_($i) set X_]
    	set y [$n_($i) set Y_]
	set ener [$n_($i) energy]
    	for {set j 0} { $j < 5} {incr j} {
    	set d_($j) [expr sqrt((pow([lindex $xlocs $j]-$x,2)) + (pow([lindex $ylocs $j]-$y,2)))]
    	puts "locs [lindex $xlocs $j] [lindex $ylocs $j] $i $d_($j)"
    		if { $d_($j) < [lindex $min $j] && $max < $ener } {
			set max $ener    			
			lset min $j $d_($j)
    			lset value $j $i
    	}
    	}
    	puts $f1 "$value"
	puts $f1 "mehak"
	
	}
	
	set clusterheadtable $value
        puts $f1 "CLUSTERHEADTABLE:$clusterheadtable"
	
	#lappend clusterheadtable myRand 1 #[expr $val(nn)-1]]
	#lappend clusterheadtable [myRand 1 [expr $val(nn)-1]]
	#lappend clusterheadtable [myRand 1 [expr $val(nn)-1]]
	#lappend clusterheadtable [myRand 1 [expr $val(nn)-1]] 
	puts "clusterheadtable $clusterheadtable"
	for {set i 0} {$i < 5} {incr i} {
		set ind [lindex $clusterheadtable $i]
		$n_($ind) color red
		$ns at [$ns now] "$n_($ind) color red"
		dict set node_list_BS($ind) node_list {}
	}
	 
	
}	

proc startframe {} {
	global ns
	set now [$ns now]
	$ns at $now setupphase
	$ns at [expr $now+0.01] steadyphase

}

# Setup phase function must be called at the start 
proc setupphase {} {
	global clusterheadtable clusterinfo_ ns n_ a_ val recv_node_CH_info_ MESSAGE_PORT faultynode
	
	for {set i 1} {$i < $val(nn) } { incr i } {
		$n_($i) color green
		$ns at [$ns now] "$n_($i) color green"
	}
	
	for {set i 0 } {$i < 5} {incr i} {
		set	clusterheadtable {}
	}
	set faultynode { }
	chooseclusterheadrandom
	for {set i 0} {$i < $val(nn)} {incr i} {
		dict set clusterinfo_($i) node {}
		dict set clusterinfo_($i) data_field {}
	}
	
	for {set i 0} {$i<5} {incr i} {
		set nn [lindex $clusterheadtable $i]
		#puts "$nn"
		set addr [$n_($nn) node-addr]
		set locx [$n_($nn) set X_]
		set locy [$n_($nn) set Y_]
		set energ [$n_($nn) energy]
		#puts "$ns at [$ns now] $a_($nn) send_message 900 1 [$n_(10) set address_] 42"
		$ns at [$ns now] "$a_($nn) send_message 900 $addr {hello $locx $locy $energ $addr}"
		
		
	}
	$ns at [expr [$ns now]+3.0] recv_ack
	
	$ns at [expr [$ns now]+12.0] "parray clusterinfo_"
	$ns at [expr [$ns now]+13.0] send_slot
	$ns at [expr [$ns now]+15.0] "parray recv_node_CH_info_"
	$ns at [expr [$ns now]+25.0] fault_tolerant
	$ns at [expr [$ns now]+30.0] steadystatephase
	$ns at [expr [$ns now]+30.0] faulty_node
	$ns at [expr [$ns now]+40.0] send_to_BS
	#$ns at [expr [$ns now]+35.0] setupphase
}	

# called after fault detection and in the Setup phase function 
proc steadystatephase {} {
	global clusterheadtable clusterinfo_ ns n_ a_ val recv_node_CH_info_ MESSAGE_PORT
	
	for {set i 0} {$i<5} {incr i} {
		set nn [lindex $clusterheadtable $i]
		#puts "$nn"
		set addr [$n_($nn) node-addr]
		set locx [$n_($nn) set X_]
		set locy [$n_($nn) set Y_]
		set energ [$n_($nn) energy]
		#puts "$ns at [$ns now] $a_($nn) send_message 900 1 [$n_(10) set address_] 42"
		$ns at [$ns now] "$a_($nn) send_message 900 $addr {data_req_msg $locx $locy $energ $addr}"
		$ns at [$ns now] contentionslot
		
	}	
}

set faultynode {} 

#sending nodelist to the base station and detection of fault
proc fault_tolerant {} {
	global clusterinfo_ ns n_ val MESSAGE_PORT clusterheadtable node_list_BS faultynode a_
	
	for { set i 0} {$i < 5} {incr i} {
		set node_list [dict get $clusterinfo_([lindex $clusterheadtable $i]) node]
		set nn [lindex $clusterheadtable $i]
		puts "sending ------------------>>>>> nodelist  $node_list"
		$ns at [$ns now] "$a_($nn) send_message 900 [$n_($nn) id] {nodelist 0 0 {$node_list} 0}"
	}
	
	
	 
}

proc faulty_node { } {
	global clusterinfo_ node_list_BS clusterheadtable a_ ns
		
		for {set i 0} {$i <5 } {incr i} {	
		set cl_no [lindex $clusterheadtable $i]
		set nnn [dict get $node_list_BS($cl_no) node_list]
		for {set j 0} {$j < [llength $nnn] } {incr j} {
			set nele [lindex $nnn $j] 
			 
			if {[lsearch $nodelis $nele] == -1} {
				lappend faultynode $nele
				puts "faulty node ------>>>>>>> $faultynode"
			}
		}
		}
		
#	for {set i 0} {$i <5 } {incr i} {
#		set cl_no [lindex $clusterheadtable $i]
#		dict set node_list_BS($cl_no) node_list [dict get $node_list_BS($cl_no) new_node_list] 
#	}	
}

$ns at 55 "parray node_list_BS"
# contention time slot can be called in the steadystate phase for new nodes to join
proc contentionslot { } {
global clusterheadtable ns n_ val xlocs ylocs node_list_BS nodelistt
	for {set i 1} {$i < $val(nn)} { incr i} {
	    	set x [$n_($i) set X_]
	    	set y [$n_($i) set Y_]
		
    		for {set j 0} { $j < 5} {incr j} {
    			set d_($j) [expr sqrt((pow([lindex $xlocs $j]-$x,2)) + (pow([lindex $ylocs $j]-$y,2)))]
    			dict lappend $nodelistt $j  
    	}
    	}
	
}


proc record {} {
	global sink f1 ns clusterheadtable
	for {set i 0} {$i < 5} {incr i} {
		set nn1 [lindex $clusterheadtable $i]
		set bw_($i) [$sink($nn1) set npkts_]
		set now [$ns now]
		set time 1.0
		puts $f1 "$now [expr $bw_($i)]"
		#$ns at [expr $now + $time] "record"
	}

}


# for receiving the acknowledgement from the nodes to join the cluster
proc recv_ack {} {
	global val recv_node_CH_info_ a_ n_ ns
	global clusterheadtable
	for {set i 1} {$i<$val(nn)} {incr i} {
		puts "sending ack $i"
		set addr [$n_($i) node-addr]
		set locx [$n_($i) set X_]
		set locy [$n_($i) set Y_]
		set energ [$n_($i) energy]
		set cond 1		
		for {set j 0} { $j < 5} { incr j} {
			set nn [lindex $clusterheadtable $j]
			if {$nn == $i} {
				set cond 0
				break			
			}
		
		}	
		puts $cond
		if {$cond==1} {
			set addr [dict get $recv_node_CH_info_($i) node_addr]
			puts $addr 
			if { [llength $addr] !=0 } {
				$ns at [expr [$ns now]] "$a_($i) send_message 900 [$n_($i) id] {ack $locx $locy $energ $addr} "
			}
		
		} 			
	}
}

# sending slots
proc send_slot {} {
	global val  a_ n_ ns clusterinfo_ clusterheadtable


	for {set i 0} {$i < 5} {incr i} {
		#puts "Sending slots"
		set nn [lindex $clusterheadtable $i]
		#puts "$nn"
		set node_mem [dict get $clusterinfo_($nn) node]
		#puts "$node_mem  [llength $node_mem]"
		for {set j 0} {$j<[llength $node_mem]} { incr j} {
			set len [llength $node_mem]
			set addr [lindex [dict get $clusterinfo_($nn) node] $j]
			$ns at [expr [$ns now]] "$a_($nn) send_message 900 [$n_($nn) id] {slot 0 [expr $len - $j] [expr $j+1] $addr} "
			
		}	
	
	}
}


# sending data collected from the nodes by the cluster head to the base station
proc send_to_BS { } {


	global val  a_ n_ ns clusterinfo_ clusterheadtable node_list_BS


	for {set i 0} {$i < 5} {incr i} {
		#puts "Sending slots"
		set nn [lindex $clusterheadtable $i]
		
		#puts "$nn"
		set data_field [dict get $clusterinfo_($nn) data_field]
		#puts "$node_mem  [llength $node_mem]"
		for {set j 0} {$j<[llength $data_field]} { incr j} {
			
			set data [lindex $data_field $j]
			set addr [lindex [dict get $clusterinfo_($nn) node] $j]
			if { [lindex $data 1] =="no_data_to_send"} {
			} else {
				$ns at [expr [$ns now]] "$a_($nn) send_message 900 [$n_($nn) id] {send_to_BS 0 0 {$data} $addr} "
			}
			
		}	
	
	}



}


proc notpresentinCH { l } {
	global clusterheadtable
	set flag 1	
	for {set i 0} { $i < 5} { incr i} {
		set nn [lindex $clusterheadtable $i]
		if {$nn == $l} {
		set flag 0
		
		}
		
	}	
	return $flag
}






for {set i 0} { $i<$val(nn)} {incr i} {

	set sink($i) [new Agent/LossMonitor]
}

for {set i 0} { $i<$val(nn)} {incr i} {

	set tcp($i) [new Agent/TCP]
}
 
 
 
 
for {set i 0} {$i < $val(nn) } {incr i} { 
	$ns attach-agent $n_($i) $sink($i)
	$ns attach-agent $n_($i) $tcp($i)
	set cbr_($i) [new Agent/CBR]
   	$ns attach-agent $n_($i) $cbr_($i)
   	$cbr_($i) set packetSize_ 1000
   	$cbr_($i) set interval_ 0.5
   	$ns connect $cbr_($i) $sink($i)
   	$ns at 3.0 "$cbr_($i) start"
   	$ns at 60.0 "$cbr_($i) stop"
}



Node instproc color { color } {
   $self instvar attr_ id_
 
   set ns [Simulator instance]
 
   set attr_(COLOR) $color
   set attr_(LCOLOR) $color
   if [$ns is-started] {
     # color must be initialized
     $ns puts-nam-config \
     [eval list "n -t [$ns now] -s $id_ -S COLOR -c $color -o $attr_(COLOR) -i $color -I $attr_(LCOLOR)"]
   }
}


#Agent/Ping instproc recv {source sport size data} {
#    $self instvar messages_seen node_
#    global ns f
#
    # extract message ID from message
#    set message_id [lindex [split $data ":"] 0]

#    if {[lsearch $messages_seen $message_id] == -1} {
#	lappend messages_seen $message_id
#	
 #       puts $f "Node [$node_ node-addr] received {[lindex $data 0]}"
#	#$self send_to_neighbors $source $sport $size $data
#    } else {
#	puts "Node [$node_ node-addr] received redundant copy of message #$message_id"
#    }
#}


Agent/Ping instproc recv {from rtt} {
	$self instvar node_
	global n_
	puts "node [$node_ id] received ping answer from \
	$from with round-trip -time $rtt ms."
	puts "node [$node_ energy] [$n_($from) energy]"
}

#set p0 [new Agent/Ping]
#$ns attach-agent $n_(0) $p0

#set p1 [new Agent/Ping]
#$ns attach-agent $n_(2) $p1

#Connect the two agents
#$ns connect $p0 $p1

#Schedule events
#$ns at 0.2 "$p0 send"
#$ns at 0.4 "$p1 send"


#$ns at 4.0 "$p_(0) start-WL-brdcast"

array set nodeinfo {}
array set dist {}
array set clusterinfo {}

for {set i 0} {$i  < $val(nn)} {incr i} {
	#set ee [expr $n_($i) energy] 
	#set ll {[$n_($i) set X_] [$n_($i) set Y_]}
	#puts "yaha tak chal rha hai"
	dict set nodeinfo($i) energ [$n_($i) energy]
	dict set nodeinfo($i) loc [$n_($i) set X_] [$n_($i) set Y_]
	if {[expr rand()] > 0.5} {
	dict set nodeinfo($i) data [expr rand()]
	} else {
	dict set nodeinfo($i) data {} 
	}
}



#updation of node information, energy and distance at each time instant

proc updatenodeinfo {} {
	global array nodeinfo {}
	global n_ val sink f1
#	global array dist { }
#  	for { set i 0} { $i < 10} {incr i} {
#	global node_($i)
# }
	
   	set ns [Simulator instance]
   	set time 1.0
	set now [$ns now]
	
  	for {set i 0} { $i < $val(nn)} {incr i} {
		#puts "[$sink($i) set nlost_]"
		dict set nodeinfo($i) dist {}
		dict set nodeinfo($i) loc {}
		dict set nodeinfo($i) energ [$n_($i) energy]
		#dict set nodeinfo($i) count 0
		
		for {set j 0} { $j < $val(nn)} {incr j} {
						
			set E1 [$n_($i) energy]
			#puts "yaha tak chal rha h"
			set E2 [$n_($j) energy]
		   	set x1 [$n_($i) set X_]
			
			set y1 [$n_($i) set Y_]
      			set x2 [$n_($j) set X_]
			set y2 [$n_($j) set Y_]
			dict set nodeinfo($i) loc $x1 $y1
			set d  [expr sqrt(pow($x1-$x2,2) + pow($y1-$y2,2))]

			dict lappend nodeinfo($i) dist $d
			
#			puts "$now ($i,$j) $d"
			
			#set dist($i$j) [expr $d]
			#lset nodeinfo($i) 0 $j $j
			#lset nodeinfo($i) 1 $j $d
		}

		puts $f1 "$now nodeinfo($i) $nodeinfo($i)"
	} 
#  set now [$ns now]
# puts "$now [expr $bw0]"
   
   	$ns at [expr $now+$time] "updatenodeinfo"
	
		
}

proc record_energy { } {
	global clusterheadtable ns  n_ f2
	
	#set Eh1 [expr 100-[$n_([lindex $clusterheadtable 0]) energy]]
	#set Eh2 [expr 100-[$n_([lindex $clusterheadtable 1]) energy]]
	#set Eh3 [expr 100-[$n_([lindex $clusterheadtable 2]) energy]]
	#set Eh4 [expr 100-[$n_([lindex $clusterheadtable 3]) energy]]
	#set Eh5 [expr 100-[$n_([lindex $clusterheadtable 4]) energy]]
	set BS [expr 100-[$n_(0) energy]]
	
	puts $f2 "$BS"
	$ns at [expr [$ns now]+1.0] record_energy
		

}


proc record_packet { } {
	global clusterheadtable ns  n_ f3 sink

	set PBS [$sink(0) set npkts_]
	
	puts $f3 "$PBS"
	$ns at [expr [$ns now]+1.0] record_packet
	
}




array set recv_node_CH_info_ {}

for {set i 0} {$i < $val(nn) } {incr i } {
	dict set recv_node_CH_info_($i) node_addr {}
	dict set recv_node_CH_info_($i) strength {}
	dict set recv_node_CH_info_($i) slotno_OW {}
	dict set recv_node_CH_info_($i) slotno_AW {}
}

array set recv_ack_info_ {}
for {set i 0} {$i < $val(nn) } {incr i} {
	dict set recv_ack_info_($i) nodes {}
}

# main program for sending and receiving the data and acknowledgement starts here
# it includes instance procedures of the classes for sending the data, broadcasting the data
# and receiving the data 
# main procedures used here are send_message which calls sendto procedure for broadcasting
# and recv for fetching the broadcasted information by the concerned node
Class Agent/MessagePassing/Flooding -superclass Agent/MessagePassing

Agent/MessagePassing/Flooding instproc send_message {size msgid msg} {
    $self instvar messages_seen node_
    global ns MESSAGE_PORT

    $ns trace-annotate "Node [$node_ node-addr] is sending {$msgid:$msg}"

    lappend messages_seen $msgid
    $self send_to_neighbors [$node_ node-addr] $MESSAGE_PORT $size "$msgid:$msg"
}



Agent/MessagePassing/Flooding instproc send_to_neighbors {skip port size data} {
    $self instvar node_ 
    global val n_ recv_node_CH_info_ clusterinfo_
    
    set message_id [lindex [split $data ":"] 0]
    set actual_message [lindex [split $data ":"] 1]
	#puts "messages  $message_id"
    
    set Ad [lindex $actual_message 0]
    puts "message-----------------> $Ad"
    if {$Ad == "hello"} {
  	for {set x 1} {$x < $val(nn)} {incr x} { 
	    set addr [$n_($x) set address_]
	    
	    if {$addr != [$node_ node-addr]} {
		#puts "$addr   [$node_ node-addr]"
		$self sendto $size $data $addr $port
	    }
	 }   

	} elseif {$Ad == "slot" || $Ad == "data_req_msg"} { 
		set node_present [dict get $clusterinfo_([$node_ node-addr]) node]
		for {set i 0} {$i <[llength $node_present]} {incr i} {
			set addr [$n_([lindex $node_present $i]) set address_ ]
			$self sendto $size $data $addr $port
		}
	} elseif {$Ad == "data"} {
		set addr [ dict get $recv_node_CH_info_([$node_ node-addr]) node_addr]
		$self sendto $size $data $addr $port
			
	} elseif { $Ad == "send_to_BS" } {
		set addr [$n_(0) node-addr]
		 $self sendto $size $data $addr $port
	} elseif {$Ad == "nodelist" } {
		set addr [$n_(0) node-addr]
		$self sendto $size $data $addr $port
		
	} else {
		
		set addr [dict get $recv_node_CH_info_([$node_ id]) node_addr]
#		puts "[$node_ node-addr] sending ack to $addr"
		$self sendto $size $data $addr $port
	}

}

Agent/MessagePassing/Flooding instproc send_to_CH {size data addr port} {
    $self instvar node_
    global val n_ 
		
		$self sendto $size $data $addr $port
}


array set node_list_BS { }



Agent/MessagePassing/Flooding instproc recv {source sport size data} {
    $self instvar messages_seen node_
    global ns f a_ MESSAGE_PORT recv_node_CH_info_ clusterinfo_ nodeinfo node_list_BS

    # extract message ID from message
    set message_id [lindex [split $data ":"] 0]
    set actual_message [lindex [split $data ":"] 1]
    set Ad [lindex $actual_message 0]
	set locx [lindex $actual_message 1]
	set locy [lindex $actual_message 2]
	set renerg [lindex $actual_message 3]
	set ack_id [lindex $actual_message 4]
	set x [$node_ set X_]
	set y [$node_ set Y_]
	
	set addr [$node_ node-addr]
#	puts "$Ad $actual_message "  

	#puts "messages  $message_id"
	
	#puts "{$data}"
	puts "[$ns now] $Ad----------->>>>>>>>  Node [$node_ node-addr] received {$data}"
	set cond 0
	

	
	if { $Ad !="slot" && $Ad!="send_to_BS" && $Ad!="nodelist"} {
	

		if {[lsearch $messages_seen $message_id] == -1 || $cond == 1} {
	
		lappend messages_seen $message_id
		if { $Ad == "hello"} {
			set D [expr sqrt(pow($x-$locx,2)+pow($y-$locy,2))]
			set strength [expr $renerg/$D]
			puts "strength---->>>>>>>>>>  $strength"
			if {[llength [dict get $recv_node_CH_info_([$node_ id]) node_addr] ]== 0} {
				dict set recv_node_CH_info_([$node_ id]) strength $strength 
				dict set recv_node_CH_info_([$node_ id]) node_addr $message_id		
				#puts "$recv_node_CH_info_([$node_ id])"
			} else {
				if {$strength > 0.1 } {
					dict set recv_node_CH_info_([$node_ id]) strength $strength 
					dict set recv_node_CH_info_([$node_ id]) node_addr $message_id
					#puts "$recv_node_CH_info_([$node_ id])"
				}
			}
	#		puts "$strength---$addr"
	#		if {$strength > 0.5} {
	#			puts "$strength----$addr"
	#			$ns at [$ns now] "$a_([$node_ node-addr]) send_message 900 $addr {ack $x $y $renerg} "
	#			$self send_to_CH [$node_ node-addr] $MESSAGE_PORT $message_id $size "$message_id:ack $x $y $renerg"
	#
	#		}
		} elseif { $Ad =="ack" } {
			if {[$node_ node-addr]==$ack_id} {
				dict lappend clusterinfo_($ack_id) node $message_id
			}
		
		} 
		    $ns trace-annotate "Node [$node_ node-addr] received {$data}"
		} elseif {$Ad == "data_req_msg" } {
				set data_present [dict get $nodeinfo([$node_ node-addr]) data]
				set addr_present [dict get $recv_node_CH_info_([$node_ id]) node_addr]
				if { [llength $data_present ] > 0} {
					
			$ns at [$ns now] "$a_([$node_ node-addr]) send_message $size [$node_ id] {data $data_present 0 0 0 $addr_present }"
				} else {
					set data_present {no_data_to_send}
			$ns at [$ns now] "$a_([$node_ node-addr]) send_message $size [$node_ id] {data $data_present 0 0 0 $addr_present }"
			
				}	
		} elseif {$Ad == "data" } {
			set data_val  "$message_id $locx"
			puts "data_val------$data_val"			
			dict lappend clusterinfo_([$node_ node-addr]) data_field $data_val
			puts "messageid----$message_id data----$locx"
		
		
		#$self send_to_neighbors $source $sport $size $data
		} else {
		$ns trace-annotate "Node [$node_ node-addr] received redundant copy of message #$message_id"
		}
	} elseif {$Ad == "send_to_BS"  } {
			if { $Ad == "send_to_BS" } {
				set data_val $renerg
				puts "Base Station [$node_ node-addr] receiving "
				puts "data_val------$data_val"			
				dict lappend clusterinfo_([$node_ node-addr]) data_field $data_val	
			} 
			
		} elseif {$Ad == "nodelist" } {
			set data_vl $renerg
			puts "Base Station [$node_ node-addr] receiving "
			puts "data_vl------>>>>>>$data_vl"			
			dict set node_list_BS($message_id) new_node_list $data_vl
			$ns at [$ns now] "parray node_list_BS"	
			#faultynode $data_vl [$node_ node-addr]
		} elseif {$Ad == "slot"} {
		
		if {[$node_ node-addr]==$ack_id} {
			puts "[$node_ node-addr]----$ack_id----$renerg"
			#puts "$renerg----"
			dict set recv_node_CH_info_([$node_ id]) slotno_OW $renerg
			dict set recv_node_CH_info_([$node_ id]) slotno_AW $locy
		}
	#} elseif {$Ad == "data_req_msg"} {
		
	#}
}


## Topology Generator

# create a bunch of nodes
#for {set i 0} {$i < $num_nodes} {incr i} {
#    set n($i) [$ns node]
#}

# create links between the nodes
#for {set g 0} {$g < $num_groups} {incr g} {
#    for {set i 0} {$i < $group_size} {incr i} {
#        $ns duplex-link $n([expr $g*$group_size+$i]) $n([expr $g*$group_size+($i+1)%$group_size]) 2Mb 15ms DropTail
#    }
#    $ns duplex-link $n([expr $g*$group_size]) $n([expr (($g+1)%$num_groups)*$group_size+2]) 2Mb 15ms DropTail
#    if {$g%2} {
#        $ns duplex-link $n([expr $g*$group_size+3]) $n([expr (($g+3)%$num_groups)*$group_size+1]) 2Mb 15ms DropTail
#    }
#}


# attach a new Agent/MessagePassing/Flooding to each node on port $MESSAGE_PORT
for {set i 0} {$i < $val(nn)} {incr i} {
    set a_($i) [new Agent/MessagePassing/Flooding]
    $n_($i) attach  $a_($i) $MESSAGE_PORT
    $a_($i) set messages_seen {}
}

proc fairness { } {
	global recv_node_CH_info_ ns n_ val f4 
	set sum 0.0
	set sum_fair 0.0
	for { set i 1} {$i < $val(nn)} { incr i} {
		if {[llength [dict get $recv_node_CH_info_($i) node_addr] ]== 0} {
			set X_($i) 0.0
		} else {
			set X_($i) 2.0	
		}
		set sum [expr $sum + $X_($i)]
		
		set fair [expr pow($X_($i),2)] 
		set sum_fair [expr $sum_fair + $fair]	
	}
	 puts "fair------> [ expr 100*$sum_fair]"
	  puts $f4 "[expr pow($sum,2)/100*$sum_fair]"
	  
	$ns at [expr [$ns now]+1.0] fairness
}



# now set up some events
#$ns at 0.2 "$a(5) send_message 900 1 {first message}"
#$ns at 0.5 "$a(17) send_message 700 2 {another one}"
#$ns at 1.0 "$a(24) send_message 500 abc {yet another one}"

#$ns at 2.0 "finish"

proc finish {} {
        global ns f nf f1 f4
        $ns flush-trace
        close $f
        close $nf
		close $f1
		close $f4
        puts "running nam..."
        exec nam simple.nam &
        exit 0
}



#Define a 'finish' procedure
#proc finish {} {
#    global ns tracefile namfile f1
#    $ns flush-trace
#    close $tracefile
#    close $namfile
#    close $f1
#    exec nam simple.nam &
#    exit 0
#}


#for {set i 0} {$i < $val(nn) } { incr i } {
#    $ns at $val(stop) "\$n_($i) reset"
#}

set count 0

proc callsetupphase { } {
	global ns count
	set count 0
	$ns at [expr [$ns now] + $count*70.0] "setupphase"
	set count [expr $count +1]
	$ns at [expr [$ns now] + $count*70.0] "callsetupphase"
	
	
	
}




#$ns at 2.0 "$Dagent_(0) startdsr"
puts "calling cluster"
#$ns at 2.0 "chooseclusterheadrandom"
puts "calling setup phase"
$ns at 3.0 "callsetupphase"
#$ns at 3.0 "setupphase"
$ns at 40.0 "record"
#$ns at 35.0 "setupphase"
$ns at 4.0 "record_energy"
$ns at 4.0 "record_packet"
$ns at 4.0 "fairness"

#$ns at 25.0 "setupphase"
$ns at $val(stop) "$ns nam-end-wireless $val(stop)"
$ns at $val(stop) "parray recv_node_CH_info_"
$ns at $val(stop) "parray clusterinfo_"
$ns at $val(stop) "finish"

$ns at $val(stop) "puts \"done\" ; $ns halt"
$ns run
#$ns run
