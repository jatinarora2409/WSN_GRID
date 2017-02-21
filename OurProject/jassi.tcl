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
set val(x)      1000                     ;# X dimension of topography
set val(y)      1000                      ;# Y dimension of topography
set val(stop)   200.0                        ;# time of simulation end
set val(energymodel)    EnergyModel     ;
set val(initialenergy) 100
set round 		1
set val(gridBoxes) 9
set MESSAGE_PORT 42 
set val(rows) 3
set val(cols) 3
set xIncrease [expr $val(x)/$val(cols)]
set yIncrease [expr $val(y)/$val(rows)]
set val(resetTime) 20




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


for {set i 0} {$i< $val(nn)} {incr i} {
	
	set xCood  [ $n_($i) set X_ ] 
	set yCood  [ $n_($i) set Y_ ]

	set xCluster [ expr $xCood / $xIncrease ]
	set yCluster [ expr $yCood / $yIncrease ]
	
	
	dict set nodeinfo_($i) clusterBoxX $xCluster
	dict set nodeinfo_($i) clusterBoxY $yCluster
	dict set nodeinfo_($i) clusterHead 0

	set output $i
	append output " "
	append output $xCood
	append output " "
	append output $yCood
	append output " "
	append output $xIncrease
	append output " "
	append output $yIncrease
	append output " "
	append output $xCluster
	append output " "
	append output $yCluster
	append output " "
	append output [lindex [dict get $nodeinfo_($i) clusterBoxX] 0]
	append output ","
	append output [lindex [dict get $nodeinfo_($i) clusterBoxY] 0] 
	#puts $output
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
	global nodeinfo_ val n_ ns
	
	for {set i 0} { $i<$val(nn)} {incr i} {
	dict set nodeinfo_($i) clusterHead 0
	$ns at [$ns now] "$n_($i) color green"	
	}

}

array set clusterhead_for_nodes {}
proc setupphase {} {
	global clusterhead_for_nodes clusterheadtable clusterinfo_ ns n_ a_ val recv_node_CH_info_ MESSAGE_PORT faultynode
	#Check the code from cbr.tcl
	resetClusterHeads
	chooseclusterheadrandom
	startTransmission
}	
array set temparray {}
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




#======================================
#setting a tcp connection between nodes
#======================================
proc startTransmission {} {
	global temparray clusterhead_for_nodes nodeinfo_ val n_ ns nn

		for { set temp 0} { $temp < $val(nn) } {incr temp} {
		set value [dict get $clusterhead_for_nodes($temp) cluster_head]
			puts "$temp : $value"
			if { $temp == $value } {
			continue
			}
			set tcp($temp) [new Agent/TCP]
			$tcp($temp) set class_ 2
			set sink($temp) [new Agent/TCPSink]
			$ns attach-agent $n_($temp) $tcp($temp)
			$ns attach-agent $n_($value) $sink($temp)
			$ns connect $tcp($temp) $sink($temp)
			set ftp($temp) [new Application/FTP]
			$ftp($temp) attach-agent $tcp($temp)
			$ns at [$ns now] " $ftp($temp) start " 
		}
			
		
				puts hello		

	#$ns at 150.0002 "puts \"NS EXITING...\" ; $ns halt"
}


	#-------------------------------------------
	# Tell nodes when the simulation ends
	#--------------------------------------------
	#for {set i 0} {$i < $val(nn) } {incr i} {
	#    $ns at 20.0 "$n_($i) reset";
	#}

	#proc stop {} {
	#    global ns_ tracefd
	#    close $tracefd
	#}




# ===================================
#      setting Up Sink       
# ===================================
#for {set i 0} { $i<$val(nn)} {incr i} {
#	set sink($i) [new Agent/LossMonitor]
#}


# ===================================
#      setting Up TCP       
# ===================================
#for {set i 0} { $i<$val(nn)} {incr i} {
#	set tcp($i) [new Agent/TCP]
#}


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


proc chooseclusterheadrandom {} {
	global clusterhead_for_nodes nodeinfo_ val n_ ns
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
					
					set output $count
					append output  " "
					append output $clusterX
					append output  " "
					append output $clusterY
					append output  " "
					append output $listOfNodes(0)
					append output  " "
					append output [array size listOfNodes]
					#puts $output

					set numberOfelements [array size listOfNodes]
					set countNumber [ expr int(rand()*$numberOfelements)]
					set clusterHeadForCluster $listOfNodes($countNumber)	
					
					dict set nodeinfo_($clusterHeadForCluster) clusterHead 1

					for {set y 0} { $y < $count } { incr y} {
						set temp $listOfNodes($y)
						dict set clusterhead_for_nodes($temp) cluster_head $listOfNodes($countNumber)
						
					}

					
					$ns at [$ns now] "$n_($clusterHeadForCluster) color red"	

		}
	}
	#puts $clusterhead_for_nodes
	}
	# global clusterheadtable ns n_ val xlocs ylocs node_list_BS f1
	# set clusterheadtable { }	
	# set min {1000 1000 1000 1000 1000}
	# set value {0 0 0 0 0 }
	# set max 0
 #    for {set i 1} {$i < $val(nn)} { incr i} {
 #    	set x [$n_($i) set X_]
 #    	set y [$n_($i) set Y_]
	# set ener [$n_($i) energy]

 #    	for {set j 0} { $j < 5} {incr j} {
 #    	set d_($j) [expr sqrt((pow([lindex $xlocs $j]-$x,2)) + (pow([lindex $ylocs $j]-$y,2)))]
 #    	puts "locs [lindex $xlocs $j] [lindex $ylocs $j] $i $d_($j)"
 #    		if { $d_($j) < [lindex $min $j] && $max < $ener } {
	# 		set max $ener    			
	# 		lset min $j $d_($j)
 #    			lset value $j $i
 #    	}
 #    	}
 #    	puts $f1 "$value"
	# puts $f1 "mehak"
	

 
 
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
$ns at 10.0 "callsetupphase"
# End the program
$ns at 250.0 "finish"

# Start the the simulation process
$ns run



