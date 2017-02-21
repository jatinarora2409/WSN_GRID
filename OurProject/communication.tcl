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
set val(ifqlen) 1000                         ;# max packet in ifq
set val(nn)     100                         ;# number of mobilenodes
set val(rp)     DSR                      ;# routing protocol
set val(x)      1000                     ;# X dimension of topography
set val(y)      1000                      ;# Y dimension of topography
set val(stop)   200.0                        ;# time of simulation end
set val(energymodel)    EnergyModel     ;
set val(initialenergy) 70
set round 		1
set val(gridBoxes) 9
set MESSAGE_PORT 42 
set val(rows) 3
set val(cols) 3
set xIncrease [expr $val(x)/$val(cols)]
set yIncrease [expr $val(y)/$val(rows)]
set val(resetTime) 70




#===================================
#        Initialization        
#===================================
#Create a ns simulator
set ns [new Simulator]

#Setup topography object
set topo       [new Topography]
$topo load_flatgrid $val(x) $val(y)
create-god $val(nn)

# Create the trace files
set tracefile [open out.tr w]
$ns trace-all $tracefile

# Create the nam files
set namfile [open out.nam w]
$ns namtrace-all $namfile
$ns namtrace-all-wireless $namfile $val(x) $val(y)
set chan [new $val(chan)];

#Create wireless channel
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
set area [expr $val(x)*$val(y)]
set area_per_node [ expr $area / $val(nn) ]
set area_for_square [expr $area_per_node * 4]
set side_float [expr sqrt($area_for_square)]
set side [expr int($side_float)]
puts $side



#===================================
#        Nodes Definition        
#===================================
set count 0
for {set i 0} {$i < $val(x)} {incr i $side} {
	for { set j 0} {$j < $val(y)} {incr j $side} {
		for { set k 0} {$k < 4} {incr k} {
			set n_($count) [$ns node]
			$n_($count) set X_ [expr {int(rand()*($side-1)+$i)}]
			$n_($count) set Y_ [expr {int(rand()*($side-1)+$j)}]
			$n_($count) set Z_ 0.0
			$ns initial_node_pos $n_($count) 20
			incr count
		}
	}
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



set clusterheadtable {}
array set nodeinfo_ {}
array set clusterinfo_ {}

for {set i 0} {$i< $val(nn)} {incr i} {
	
	set xCood  [ $n_($i) set X_ ] 
	set yCood  [ $n_($i) set Y_ ]

	set xCluster [ expr $xCood / $xIncrease ]
	set yCluster [ expr $yCood / $yIncrease ]
	
	
	dict set nodeinfo_($i) clusterBoxX $xCluster
	dict set nodeinfo_($i) clusterBoxY $yCluster
	dict set nodeinfo_($i) clusterHead 100

	if {[expr rand()] > 0.2} {
	dict set nodeinfo_($i) data [expr rand()]
	} else {
	dict set nodeinfo_($i) data {} 
	}

}

for {set i 0} { $i<$val(nn)} {incr i} {

	set sink($i) [new Agent/LossMonitor]
}

for {set i 0} { $i<$val(nn)} {incr i} {

	set tcp($i) [new Agent/TCP]
}


#this call setup phase after every 70 units of time
proc callsetupphase { } {
	global ns count val
	set count 0
	$ns at [expr [$ns now] + $count*$val(resetTime)] "setupphase"
	set count [expr $count +1]
	$ns at [expr [$ns now] + $count*$val(resetTime)] "callsetupphase"
}

proc resetClusterHeads {} {
	global nodeinfo_ val n_ ns clusterheadtable
	
	for {set i 0} { $i<$val(nn)} {incr i} {
	dict set nodeinfo_($i) clusterHead 100
	$ns at [$ns now] "$n_($i) color green"	
	}
	array unset clusterheadtable

}

proc setupphase {} {
	global clusterheadtable clusterinfo_ ns n_ a_ val recv_node_CH_info_ MESSAGE_PORT faultynode
	#Check the code from cbr.tcl
	resetClusterHeads
	chooseclusterheadrandom

	for {set i 0} {$i < $val(nn)} {incr i} {
		dict set clusterinfo_($i) node {}
		dict set clusterinfo_($i) data_field {}
	}

	set clusterHeadCount [array size clusterheadtable]
	#puts $clusterHeadCount

	for {set i 0} {$i< 9} {incr i} {
		set nn [lindex $clusterheadtable $i]
		#puts "$nn"
		set addr [$n_($nn) node-addr]
		set locx [$n_($nn) set X_]
		set locy [$n_($nn) set Y_]
		set energ [$n_($nn) energy]
		#puts "$a_($nn) send_message 900 $addr {hello $locx $locy $energ $addr}"
		$ns at [$ns now] "$a_($nn) send_message 900 $addr {hello $locx $locy $energ $addr $nn}"
	}
	$ns at [expr [$ns now]+50.0] "parray clusterinfo_"
	$ns at [expr [$ns now]+20.0] steadystatephase
	
}	

#====================================
# writing to a file the node content
#====================================
set fp [open "node_data.txt" w+]
for { set i 0} { $i<$val(nn)} {incr i} {
	set t [ expr rand() * 10000 ] 
	set s1 $i 
	append s1 " this is the content of node :"
	append s1 $t
	puts $fp $s1
}
close $fp




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

proc steadystatephase {} {
	global clusterheadtable clusterinfo_ ns n_ a_ val recv_node_CH_info_ MESSAGE_PORT nodeinfo_
for { set i 0} { $i<9} {incr i} {
		#puts "$nn"
		set nn [lindex $clusterheadtable $i]
		set addr [$n_($nn) node-addr]
		set locx [$n_($nn) set X_]
		set locy [$n_($nn) set Y_]
		set energ [$n_($nn) energy]
			#puts "$ns at [$ns now] $a_($nn) send_message 900 1 [$n_(10) set address_] 42"
			$ns at [$ns now] "$a_($nn) send_message  900  $addr {data_req_msg $locx $locy $energ $addr}  "
			$ns at [expr [$ns now]+20] "$a_($nn) send_message  900  $addr {data_req_msg $locx $locy $energ $addr}  "
	
	}

}


proc chooseclusterheadrandom {} {
	global nodeinfo_ val n_ ns clusterheadtable 
	set value {}
			for {set i 0} { $i < $val(rows)} {incr i} {
				for {set j 0} { $j < $val(cols)} {incr j} {
					set clusterX $i
					set clusterY $j
					set count 0
					array unset listOfNodes
					
						for {set k 0} { $k < $val(nn) } { incr k} {
							if { [lindex [dict get $nodeinfo_($k) clusterBoxX] 0] == $clusterX && [lindex [dict get $nodeinfo_($k) clusterBoxY] 0] == $clusterY } {
									set listOfNodes($count) $k
									incr count
							}
						}
					
				
					set numberOfelements [array size listOfNodes]
					set countNumber [ expr int(rand()*$numberOfelements)]
					set clusterHeadForCluster $listOfNodes($countNumber)	
					lappend value $clusterHeadForCluster


					for {set k 0} { $k < $count } { incr k} {
							dict set nodeinfo_($listOfNodes($k)) clusterHead $clusterHeadForCluster
						}


					dict set nodeinfo_($clusterHeadForCluster) clusterHead 100

					
					$ns at [$ns now] "$n_($clusterHeadForCluster) color red"	

		}
	}
	set clusterheadtable $value
	puts  "CLUSTERHEADTABLE:$clusterheadtable"
	#puts $clusterhead_for_nodes
	}
	
Agent/Ping instproc recv {from rtt} {
	$self instvar node_
	global n_
	puts "node [$node_ id] received ping answer from \
	$from with round-trip -time $rtt ms."
	puts "node [$node_ energy] [$n_($from) energy]"
}

for {set i 0} { $i<$val(nn)} {incr i} {

	set sink($i) [new Agent/LossMonitor]
}

for {set i 0} { $i<$val(nn)} {incr i} {

	set tcp($i) [new Agent/TCP]
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

   # $ns trace-annotate "Node [$node_ node-addr] is sending {$msgid:$msg}"
    puts " [$ns now] Node [$node_ node-addr] is sending {$msgid:$msg}"
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
  #  puts "message-----------------> $Ad"
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
    global ns f a_ MESSAGE_PORT recv_node_CH_info_ clusterinfo_ nodeinfo_ node_list_BS

    # extract message ID from message
    set message_id [lindex [split $data ":"] 0]
    set actual_message [lindex [split $data ":"] 1]
    set Ad [lindex $actual_message 0]
	set locx [lindex $actual_message 1]
	set locy [lindex $actual_message 2]
	set renerg [lindex $actual_message 3]
	set ack_id [lindex $actual_message 4]
	set clusterHeadNumber [lindex $actual_message 5]
	set x [$node_ set X_]
	set y [$node_ set Y_]
	
	set addr [$node_ node-addr]
#	puts "$Ad $actual_message "  

	#puts "messages  $message_id"
	
	#puts "{$data}"
	#puts "[$ns now] $Ad----------->>>>>>>>  Node [$node_ node-addr] received {$data}"
	set cond 0
	

	
	if { $Ad !="slot" && $Ad!="send_to_BS" && $Ad!="nodelist"} {
	

		if {[lsearch $messages_seen $message_id] == -1 || $cond == 1} {
	
		lappend messages_seen $message_id
		if { $Ad == "hello"} {
			set myClusterhead [dict get $nodeinfo_([$node_ id]) clusterHead]
			if { $myClusterhead == $clusterHeadNumber } {

			#	puts [$node_ id]
				#puts "clusterHeadInfosaved"
				set energyNode [$node_ energy]
				set addrNode [$node_ node-addr]
	
				dict set recv_node_CH_info_([$node_ id]) node_addr $message_id		
				$ns at [expr [$ns now]] "$a_([$node_ id]) send_message 900 [$node_ id] {ack $x $y $energyNode $message_id } "
		
				#puts "$recv_node_CH_info_([$node_ id])"
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
		    #$ns trace-annotate "Node [$node_ node-addr] received {$data}"
		} elseif {$Ad == "data_req_msg" } {
				set data_present [dict get $nodeinfo_([$node_ node-addr]) data]
				set addr_present [dict get $recv_node_CH_info_([$node_ id]) node_addr]
				if { [llength $data_present ] > 0} {
			$ns at [$ns now] "$a_([$node_ node-addr]) send_message $size [$node_ id] {data $data_present 0 0 0 $addr_present }"
				} else {
					set data_present {no_data_to_send}
			$ns at [$ns now] "$a_([$node_ node-addr]) send_message $size [$node_ id] {data $data_present 0 0 0 $addr_present }"
			
				}	
		} elseif {$Ad == "data" } {
			set data_val  "$message_id $locx"
			#puts "data_val------$data_val"			
			dict lappend clusterinfo_([$node_ node-addr]) data_field $data_val
			#puts "messageid----$message_id data----$locx"
		
		
		#$self send_to_neighbors $source $sport $size $data
		} else {
	#	$ns trace-annotate "Node [$node_ node-addr] received redundant copy of message #$message_id"
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
 
 for {set i 0} {$i < $val(nn)} {incr i} {
    set a_($i) [new Agent/MessagePassing/Flooding]
    $n_($i) attach  $a_($i) $MESSAGE_PORT
    $a_($i) set messages_seen {}
}

#for {set i 0} {$i < $val(nn) } {incr i} { 
#	$ns attach-agent $n_($i) $sink($i)
#	$ns attach-agent $n_($i) $tcp($i)
#	set cbr_($i) [new Application/Traffic/CBR]
#	$cbr_($i) set packetSize_ 500
#	$cbr_($i) set interval_ 0.005
#	$cbr_($i) attach-agent  $tcp($i)
	#  	$ns attach-agent $tcp($i) $sink($i)
	#  	$ns connect $tcp($i) $sink([expr $i-1])
   	# 	$ns at 1.0 "$cbr_($i) s
proc finish {} {
global ns tracefile namfile
$ns flush-trace
puts "running nam..."
close $tracefile
close $namfile
exec nam out.nam &
exit 0
}



puts "calling cluster"
#$ns at 2.0 "chooseclusterheadrandom"
puts "calling setup phase"
$ns at 1.0 "callsetupphase"
# End the program
$ns at 250.0 "finish"

# Start the the simulation process
$ns run



