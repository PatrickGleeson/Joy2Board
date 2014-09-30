#!/bin/bash

# Load the configuration

declare -A keystroke
declare -A keystroke_name

load_config(){
	# Skip ahead until the Device
	read tmp
	while [ "$tmp" != "Device" ]; do
		read tmp
	done
	# Read in the device to be used
	read device
	
	# Skip ahead until the Groups
	read tmp
	while [ "$tmp" != "Groups" ]; do
		read tmp
	done
	# Read in groups
	group_num=0
	read input_type input_number input_threshold name
	while [ "$input_type" != "Members" ]; do
		if [ "$input_type" = "" ]; then
			read input_type input_number input_threshold name
			continue
		fi
		if [ "$input_type" = "axis" ]; then
			group_input[$group_num]="2_"$input_number
			group_input_threshold[$group_num]=$input_threshold
			group_name[$group_num]=$name
			group_num=$group_num+1
		fi
		if [ "$input_type" = "button" ]; then
			group_input[$group_num]="1_"$input_number
			group_name[$group_num]=$name
			group_num=$group_num+1
		fi
		read input_type input_number input_threshold name 
	done
	
	# Read in members
	member_num=0
	read input_type input_number input_threshold name
	while [ "$input_type" != "Solos" ]; do
		if [ "$input_type" = "" ]; then
			read input_type input_number input_threshold name
			continue
		fi
		if [ "$input_type" = "axis" ]; then
			member_input[$member_num]="2_"$input_number
			member_input_threshold[$member_num]=$input_threshold
			member_name[$member_num]=$name
			member_num=$member_num+1
		fi
		if [ "$input_type" = "button" ]; then
			member_input[$member_num]="1_"$input_number
			member_name[$member_num]=$name
			member_num=$member_num+1
		fi
		read input_type input_number input_threshold name 
	done
	
	# Read in solos
	solo_num=0
	read input_type input_number input_threshold key name
	while [ "$input_type" != "Keystrokes" ]; do
		if [ "$input_type" = "" ]; then
			read input_type input_number input_threshold key name
			continue
		fi
		if [ "$input_type" = "axis" ]; then
			solo_input[$solo_num]="2_"$input_number
			solo_input_threshold[$solo_num]=$input_threshold
			solo_key[$solo_num]=$key
			# No use for name yet
			solo_num=$solo_num+1
		fi
		if [ "$input_type" = "button" ]; then
			solo_input[$solo_num]="1_"$input_number
			solo_key[$solo_num]=$key
			# No use for name yet
			solo_num=$solo_num+1
		fi
		read input_type input_number input_threshold key name
	done

	
	# Read in keystrokes
	read group member key name 
	while [ "$group" != "Done" ]; do
		if [ "$group" = "" ]; then
			read group member key name
			continue
		fi
		keystroke[$group"_"$member]=$key
		if [ "$name" = "" ]; then
			keystroke_name[$group"_"$member]=$key
		else
			keystroke_name[$group"_"$member]=$name
		fi
		read group member key name
	done
	
	# Skip through the rest of the file
	#while read junk; do
	#	continue
	#done
	
	return
}

load_config < config

echo done

current_group=0

print_status () {
	echo -e '\E[37;44m'"\033[1m${group_name[$current_group]}\033[0m"
	echo "	${keystroke_name[$current_group'_0']}"
	echo "${keystroke_name[$current_group'_8']}"
	echo "    ${keystroke_name[$current_group'_1']}	    ${keystroke_name[$current_group'_2']}"
	echo ""
	echo "	${keystroke_name[$current_group'_3']}"
	echo ""
	echo "    ${keystroke_name[$current_group'_4']}"
	echo ""
	echo "${keystroke_name[$current_group'_5']}	${keystroke_name[$current_group'_6']}"
	echo ""
	echo "    ${keystroke_name[$current_group'_7']}"
}

process_event () {
read JUNK
read JUNK t JUNK
if [ "$t" != $device ]; then
	echo $t
	return
fi

while true; do	
	read JUNK JUNK input_type JUNK input_time JUNK input_number JUNK input_value	
	
	input_type=${input_type%,}
	input_time=${input_time%,}
	input_number=${input_number%,}
	input_value=${input_value%,}
	input_hash=$input_type"_"$input_number 
	
	# Check for group input		
	for i in `seq 0 ${#group_input[*]}`; do
		if [ "$input_hash" = "${group_input[$i]}" ]; then
			if [ "$input_type" = "2" ]; then # it's an axis 
				if [ ${group_input_threshold[$i]} -gt 0 ]; then # it's moving the axis positively
					if [ "$input_value" -ge "${group_input_threshold[$i]}" ]; then
						current_group=$i
						print_status
						continue 2
					fi
				else # it's moving the axis negatively
					if [ "$input_value" -le "${group_input_threshold[$i]}" ]; then
						current_group=$i
						print_status
						continue 2						
					fi
				fi
			else # it's a button
				if [ "$input_value" = "1" ]; then
					current_group=$i
					print_status
					continue 2
				fi
			fi
		fi
	done
	
	# Check for member input
	for i in `seq 0 ${#member_input[*]}`; do
		if [ "$input_hash" = "${member_input[$i]}" ]; then
			if [ "$input_type" = "2" ]; then # it's an axis
				#echo ${member_input_threshold[$i]} 
				if [ ${member_input_threshold[$i]} -gt 0 ]; then # it's moving the axis positively
					if [ "$input_value" -ge "${member_input_threshold[$i]}" ]; then
						#echo Keydown group $current_group member $i key ${keystroke[$current_group"_"$i]}
						xdotool keydown ${keystroke[$current_group"_"$i]}
						member_down[$i]=1
						print_status
						continue 2
					else
						if [ "${member_down[$i]}" = "1" ]; then
							#echo Keyup group $current_group member $i key ${keystroke[$current_group"_"$i]}
							xdotool keyup ${keystroke[$current_group"_"$i]}
							member_down[$i]=0
							print_status
							continue 2
						fi
					fi
				else # it's moving the axis negatively
					if [ "$input_value" -le "${member_input_threshold[$i]}" ]; then
						#echo Keydown group $current_group member $i key ${keystroke[$current_group"_"$i]}
						xdotool keydown ${keystroke[$current_group"_"$i]}
						member_down[$i]="1"
						print_status
						continue 2
					else
						if [ "${member_down[$i]}" = "1" ]; then
							#echo Keyup group $current_group member $i key ${keystroke[$current_group"_"$i]}
							xdotool keyup ${keystroke[$current_group"_"$i]}
							member_down[$i]="0"
							print_status
							continue 2
						fi
					fi
				fi
			else # it's a button
				if [ "$input_value" = "1" ]; then
					#echo Keydown group $current_group member $i key ${keystroke[$current_group"_"$i]}
					xdotool keydown ${keystroke[$current_group"_"$i]}
					continue 2
				else
					#echo Keyup group $current_group member $i key ${keystroke[$current_group"_"$i]}
					xdotool keyup ${keystroke[$current_group"_"$i]}
					continue 2
				fi
			fi
		fi
	done
	
	#Check for solo input
	for i in `seq 0 ${#solo_input[*]}`; do
		if [ "$input_hash" = "${solo_input[$i]}" ]; then
			if [ "$input_type" = "2" ]; then # it's an axis 
				if [ ${solo_input_threshold[$i]} -gt 0 ]; then # it's moving the axis positively
					if [ "$input_value" -ge "${solo_input_threshold[$i]}" ]; then
						#echo Keydown solo number $i key ${solo_key[$i]}
						xdotool keydown ${solo_key[$i]}
						continue 2
					else
						#echo Keyup solo number $i key ${solo_key[$i]}
						xdotool keyup ${solo_key[$i]}
						continue 2
					fi
				else # it's moving the axis negatively
					if [ "$input_value" -le "${solo_input_threshold[$i]}" ]; then
						#echo Keydown solo number $i key ${solo_key[$i]}
						xdotool keydown ${solo_key[$i]}
						continue 2
					else
						#echo Keyup solo number $i key ${solo_key[$i]}
						xdotool keyup ${solo_key[$i]}
						continue 2
					fi
				fi
			else # it's a button
				if [ "$input_value" = "1" ]; then
					#echo Keydown solo number $i key ${solo_key[$i]}
					xdotool keydown ${solo_key[$i]}
					continue 2
				else
					#echo Keyup solo number $i key ${solo_key[$i]}
					xdotool keyup ${solo_key[$i]}
					continue 2
				fi
			fi
		fi
	done
	
done
}

jstest --event /dev/input/js0 | process_event
jstest --event /dev/input/js1 | process_event

