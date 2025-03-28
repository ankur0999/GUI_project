namespace eval functions {
   
    proc kill_main_pdf {} {
	    catch {
		set pid [exec pgrep -f "evince.*main.pdf"]
		if {[string is digit $pid]} {
		    exec kill $pid
		}
	    } result
   }
    
    
    # This is on_close funtion
    # It asks the user whether he wants to save the changes he has made in the program
    # Or want to close wihtout saving them
    proc on_close {} {
        global has_unsaved_changes ;
    
        # IF no changes has been made, close the progam wihout taking re-confirmation 
        if { $has_unsaved_changes eq "false" } {
            kill_main_pdf;
            exit 0
        }

        set response [tk_messageBox -type yesnocancel -icon question -title "Exit" \
            -message "Do you want to save the changes before exiting?"]

        if {$response == "yes"} {
            save_changes  ;# Call your save function here
            kill_main_pdf;
            exit 0
        } elseif {$response == "no"} {
            kill_main_pdf
            exit 0
        } else {
             return  ;# Do nothing, user canceled exit
        }
    }
    
    
    
	# Function to handle selection change
	proc on_combobox_select {} {
	    global current_index tex_ids has_unsaved_changes;

	    # Get selected value from the combobox
	    set selected_id [.top.id_combo get]

	    # Save current page status before switching
	    save_current_status

	    # Find the index of the selected item
	    set index [lsearch -exact $tex_ids $selected_id]
	    
	    if {$index != -1} {
		set current_index $index
		go_to_page $selected_id  ;# Navigate to the selected page
	    }
	    
	}

    # To get the list of entries of TexFileSequence.csv file
	proc load_tex_files {file_path} {
	    if {![file exists $file_path]} {
		 tk_messageBox -message "Error: .TexFileSequence.csv not found!" -icon error  -title "Error";
		 return {}
	    }

	    set fp [open $file_path r]
	    set tex_files [split [read $fp] "\n"]
	    close $fp

	    set tex_ids [list]
	    foreach file $tex_files {
		set trimmed_file [string trim $file]
		if {$trimmed_file ne ""} {
		    lappend tex_ids $trimmed_file
		}
	    }
	    return $tex_ids
	}
	
	
	
	#***************
	proc filter_combobox {event} {
	    global tex_ids

	    set input [.top.id_combo get]  ;# Get the current text from combobox
	    set filtered_list [list]
	    if {$event eq "click"} {
		# If clicked, show the full list
		set filtered_list $tex_ids
	    } else {
		# If typing, filter the list based on input
		foreach item $tex_ids {
		    if {[string match "*$input*" $item]} {
		        lappend filtered_list $item
		    }
		}
	    }

	    # Update combobox values dynamically
	    .top.id_combo configure -values $filtered_list

	    # Manually open the dropdown
	    after 100 { event generate .top.id_combo <Down> }
	    

	}

	

	
	#***************
	
	
	proc show_full_list {} {
	    global tex_ids
	    .top.id_combo configure -values $tex_ids  ;# Restore full list
	    # .top.id_combo set [lindex $tex_ids 0]     ;# Set the first item as selected
	}

	
	# it count the panes it has
	proc count_panes {filename} {
	    set content [read_from_file $filename];

	    # Count occurrences of \setpanenumber{n}
	    set count 0
	    foreach line [split $content "\n"] {
		if {[regexp {\\setpanenumber\{(\d+)\}} $line -> pane]} {
		    if {$pane > $count} {
		        set count $pane
		    }
		}
	    }
	    return $count
	}
	
	
	proc generate_pane_list {max_panes} {
	    set pane_list {}
	    for {set i 1} {$i <= $max_panes} {incr i} {
		lappend pane_list $i
	    }
	    return $pane_list
	}
	
	
	# function to add marks
	proc add_marks { args } {
	    global main_file has_unsaved_changes num_checkboxes  ;# Access global variables
	    set has_unsaved_changes "true" ;# update the variable
	    set new_marks ""
	    set sum 0
	    
	    #calculate the new value of putMarks and total marks of the student
	    for {set i 0} {$i < $num_checkboxes} {incr i} {
		 set varName "cbVar$i"   ;# Create the variable name dynamically
		 global $varName         ;# Declare it as a global variable
		 
		 #Arguments are passed only if someone adds marks using marks entryField
		 if { [llength $args] > 0 } {
		     set new_marks  [lindex $args 0];
		     set $varName 0 ;#Unmark all the checkboxes
		 } else {
		     append new_marks "[set $varName]+" ;# Get the actual value
		     set sum [expr {$sum + [set $varName]}] ;# Get and add the actual value
		 }
	    }
	    
	    #remove the trailing "+" only if checkbox to enter marks
	    if { ([llength $args] == 0) } {
		set new_marks [string range $new_marks 0 end-1]
		#Update the entry field
		.marks.entry delete 0 end;
		.marks.entry insert 0 $sum;
	    }
	    
	    # Open the file in read mode and read its content
	    set fileContent [read_from_file $main_file]
	    
	    # getting matched pane content from read_pane function
	    set matched_pane [read_pane];
	    
	    if { $matched_pane eq "" } {
	        puts "there is problem in latex file."
	        return
	    }
	    
	    
	    # determine putmarks position in main.tex (start_index & end_index )
	    set start_index [find_first_match_index $matched_pane "\\putmarks"];
	    if { $start_index == -1 } return;
	    set sub_input [string range $matched_pane $start_index end]
	    set end_index [find_first_match_index $sub_input "\}"];
	    if { $end_index == -1 } return ;
	    
	    # Replace old_marks with new_marks i.e.
	    # old_marks = \putmarks{2+4+0+0}
	    # new_marks = \putmarks{2+0+4+4}
	    set modifiedContent [string replace $matched_pane $start_index [expr {$start_index + $end_index}] "\\putmarks\{$new_marks\}"]
	    
	    
	    # Replace the matched pane content with the modified one in the entire file
	    set modifiedFileContent [string map [list $matched_pane $modifiedContent] $fileContent] 
	     
	    # Open the file in write mode and write the modified content back
	    write_to_file $main_file $modifiedFileContent;
	    puts "Marks updated successfully."
	    
	    # Compile the tex file into PDF
	    update_ui ;# Function call: update_ui 
	}
	
	
	
    
	# Function to reset the timer
	proc add_marks_timer {} {
	    global has_unsaved_changes   ;# Access global variables
	    set has_unsaved_changes "true" ;# update the variable
	    
	    set new_marks [.marks.entry get ]

	    # Check if new_marks is a valid floating point number
	    if { ![string is double -strict $new_marks] } {
		 puts "Invalid entry: $new_marks is not a number"
		return;
	    } 

	    
	    after cancel $::marks_timer_id  ; # Cancel any existing timer
	    set ::marks_timer_id [after 750 [list functions::add_marks $new_marks]]  ; # Set a new timer for 0.750 seconds
	}
	
	
	
	
	
	proc update_ui {} {
	    global curr_dir;
	    
	    #create variable 
	    convert_tex_to_pdf	;#function call
	   
	}
	
	
	
	
	# Function to convert .tex to .pdf
	proc convert_tex_to_pdf { } {
	    global curr_dir
	    
	    # string main.tex
            set main_tex "main.tex"
	   
	    # Construct full path to the .tex file
	    set tex_file "$curr_dir/$main_tex"

	     # Make sure main.tex exist	
	    if {![file exists $tex_file]} {
		tk_messageBox -message "Error: File not found!\n$tex_file" -icon error  -title "Error"
		return
	    }
	    
	    # function call: Compile the tex into pdf
    	    run_pdflatex $main_tex

	}
	
	
	
	
	
	# Check if the pdf was generated 
	proc check_pdf_generation {pdf_file} {
	    if {![file exists $pdf_file]} {
		return
	    }
	    
	    # Open the new PDF file with Evince
	    exec evince $pdf_file &
	}
	
	
	
	
	# function to read a particular pane
	proc read_pane {} {
	    global selected_pane main_file;
	    
	    # Ensure selected_pane is valid
	    if {![string is integer -strict $selected_pane] || $selected_pane < 1} {
		puts "Invalid pane selection: $selected_pane"
		return
	    }
	    
	    set default_pane 1
	    
	     # Read file content
	    set fp [open $main_file r]
	    set content [read $fp]
	    close $fp
	     
	     ## Improved regex to match the specific pane section
	    set pane_regex "\\\\setpanenumber\\{$selected_pane\\}\\s*(.*?)(?=\\\\setpanenumber\\{|\\\\end\\    {document\\}}|\\\\newpage)"
	    
	     #   Try to match the selected pane
	    set match_list [regexp -inline -expanded $pane_regex $content]
	    
	     # If the selected pane doesn't exist, fallback to pane 1
	    if {[llength $match_list] == 0 && $selected_pane != $default_pane} {
		set pane_regex "\\\\setpanenumber\\{$default_pane\\}\\s*(.*?)(?=\\\\setpanenumber\\{|\\\\end\\{document\\}}|\\\\newpage)"
		set match_list [regexp -inline -expanded $pane_regex $content]
	     }

	    # If a match is found, extract the pane content
	    if {[llength $match_list] > 0} {
		set matched_pane [lindex $match_list 0]
	    } else {
		puts "Pane $default_pane not found! Check the LaTeX file structure."
		return ""
	    }
	    
	    return $matched_pane
        }
	
	
	
	#To determine the marks update source i.e. entryField or checkboxes
	proc is_manual_marks_entry { markingScheme putmarks } {
	    #If markingScheme and putMarks differ in length,
	    #then marks were updated using marks entryField
	    if { [llength $markingScheme] != [llength $putmarks] } {
		return "yes";
	    } else {
		# Split markingScheme and putmarks by '+'
		set putmarks_list [split $putmarks "+"];
		set marks_list [split $markingScheme "+"];
		
		# Get the size of the marks list (both lists should have the same size here)
		set size [llength $marks_list]
		
		# Compare each element
		for {set i 0 } { $i < $size } { incr i } {
		    if { ([lindex $putmarks_list $i] != [lindex $marks_list $i]) && ([lindex $putmarks_list $i] != 0) } {
		        return "yes"  ;# Marks were updated manually
		    }
		}
		
		# If all values match, return "no"	
		return "no";
	    }
	}
	
	
	
	# function to read marks from main
	proc update_marks {} {
	
	    # getting matched pane content from read_pane function
	    set matched_pane [read_pane];
	    if { $matched_pane eq "" } {
	        puts "there is problem in latex file."
	        return
	    }
	    
	    
	     # find index of "\showmarkingscheme" in file
	    set start_index [find_first_match_index $matched_pane "\\showmarkingscheme"]
	    if { $start_index == -1 } return;
	    
	    # sub_file ,containg data of $matched_pane, start_index onward
	    set sub_input [string range $matched_pane $start_index end]
	    set end_index [find_first_match_index $sub_input "\}"];    
	    if { $end_index == -1 } return;
	    set match_part [string range $sub_input 0 $end_index]
	    
	    #extract content between curly braces { }
	    regexp "\\\\showmarkingscheme(.*)" $match_part -> markingScheme
	    
	    # Trim whitespaces
	    set markingScheme [string trim $markingScheme]
	    
	    #remove the first "{" and last "}" brace
	    set markingScheme [string range $markingScheme 1 end-1]
	    
	    # remove whitespaces between marks
	    set markingScheme [regsub -all {\s+} $markingScheme ""];
	    
	    
	    #if markingscheme is not present, disable the mark field
	    if { $markingScheme eq "" } {
		.marks.entry delete 0 end;                    ;# delete the value
		.marks.entry configure -state disabled        ;# disable the button
		.marks.label configure -state disabled    ;# Change label color
	    } else {
		.marks.entry configure -state normal          ;# make the state normal
		.marks.label configure -state normal     ;# Restore original color
	    }


	    # Extract putmarks values for checkbox selection
	    set start_index [find_first_match_index $matched_pane "\\putmarks"];
	    if { $start_index == -1 } return;
	    
	    set sub_input [string range $matched_pane $start_index end]
	    set end_index [find_first_match_index $sub_input "\}"];
	    if { $end_index == -1 } return ;
	    set match_part [string range $sub_input 0 $end_index]
	    
	    regexp "\\\\putmarks(.*)" $match_part -> putmarks
	    # Trim whitespaces
	    set putmarks [string trim $putmarks]
	    
	    #remove the first "{" and last "}" brace
	    set putmarks [string range $putmarks 1 end-1]
	    
	    # remove whitespaces between marks
	    set putmarks [regsub -all {\s+} $putmarks ""];

	    # Count number of checkboxes to be created
	    global num_checkboxes 0; 
	    set num_checkboxes [llength [split $markingScheme "+"]]  ;# number of checkboxes

	    # Parse putmarks and marks strings into a lists
	    set putmarks_list [split $putmarks +];
	    set marks_list [split $markingScheme +];

	    # Remove existing checkboxes
	    foreach w [winfo children .marks] {
		if {[string match ".marks.cb*" $w]} {
		    destroy $w
		}
	    }
	    
	    set sum 0;
	    # Create checkboxes dynamically
	    for {set i 0} {$i < $num_checkboxes} {incr i} {
		set varName "cbVar$i"
		global $varName
		set $varName 0   ;# Default value is 0 (unchecked)

		# Get the value from marks_list
		set marks_val [lindex $marks_list $i] ; 
		
		#To determine the marks update source i.e. entryField or checkboxes
		if { [is_manual_marks_entry $markingScheme $putmarks] eq "yes" } {
		    # Code for when marks were updated via the entry field
		    set $varName 0 ;#Unmark the checkboxes
		    set sum [lindex $putmarks_list 0]
		} else {
		    # Code for when marks were updated via checkboxes
		    set putmark_val [lindex $putmarks_list $i] ; # Get the value from putmarks_list
		    if { $putmark_val != "0" } {
			set $varName $putmark_val  ;# Assign the actual value, 0 = unmarked, 0 < marked
			set sum [expr {$sum + $putmark_val}] ;#update the sum
		    }
		}
		
		
		# Use variable reference (global scope)
		checkbutton .marks.cb$i -text "$marks_val" -variable $varName -onvalue $marks_val -offvalue 0 -font myFont -command functions::add_marks
		grid .marks.cb$i -row 0 -column [expr {$i + 2}] -padx 3
	    }
	    
	    .marks.entry delete 0 end ;#delete everything 
	    .marks.entry insert 0 $sum ;#set the sum as marks
	
	
	}
	
	
	
	
	
	
	# function to read comment from main
	proc update_comment {} {
	    global selected_position main_file;# Access global variables
        
	    # getting matched pane content from read_pane function
	    set matched_pane [read_pane];
	    
	    if { $matched_pane eq "" } {
	        puts "there is problem in latex file."
	        return
	    }
	    
	    # Locate the first occurrence of \putcommentT or \putcommentB
	    set start_index [find_first_match_index $matched_pane "\\putcomment$selected_position"]
	    if {$start_index == -1} {
		.right_comment.text delete 1.0 end  ; # Clear the existing content if no match is found
		puts "No match found for: \\putcomment$selected_position."
		return
	    }

	    # Extract substring from that position
	    set sub_input [string range $matched_pane $start_index end]

	    # Find the first occurrence of \nextcommandmarker after \putcomment
	    set end_index [string first "\\nextcommandmarker" $sub_input]
	    if {$end_index == -1} {
		.right_comment.text delete 1.0 end  ; # Clear the existing content if no match is found
		puts "No match found for: \\nextcommandmarker."
		return
	    }

	    # Extract only up to the first \nextcommandmarker
	    set match_part [string range $sub_input 0 [expr {$end_index - 1}]]
	    
	   
	    # Initialize comment variables with default values
	    set comment ""
	    
	    # Extract the comment part within { }
	    if {[regexp "\\\\putcomment${selected_position}(.*)" $match_part -> comment]} {
		# Trim whitespaces
		set comment [string trim $comment]
		
		#remove the first "{" and last "}" characters
		set comment [string range $comment 1 end-1]

		# Update the text box with the extracted comment
		.right_comment.text delete 1.0 end  ; # Clear the existing content in the text box
		.right_comment.text insert end $comment  ; # Insert the new comment value
	    } else {
		.right_comment.text delete 1.0 end  ; # Clear the existing content if no match is found
		puts "No valid comment found."
	    }
	    
	}
	
	
	
	
	
	proc on_selected_tab_change { pane varName element op} {
    
	    update_comment; # get comment from the main file
	    if { $pane eq "" } {
	        return
	    }
	    update_marks; # get marks from the main file
	}
	
	
	
	
	# creating a main file
	proc create_main {} {
	    global curr_dir main_file current_file;
	    set tex_file_name [.top.id_combo get];
	    set current_file $tex_file_name
	    
	    # Check if file exists
	    if { ![file exist $tex_file_path] } {
		puts "file $tex_file_name.tex doesn't exist";
		return ;
	    }
	    set tex_file_path "$curr_dir/$tex_file_name.tex"  
	    exec cp $tex_file_path $main_file;
	    
		
	}
	
	
	# Define the add_comment function
	proc add_comment { new_comment} {
	    global selected_position main_file has_unsaved_changes ;# Access global variables
	    
	    #update the variable
	    set has_unsaved_changes "true";
	    
	    # read file content
	    set fileContent [read_from_file $main_file];
	    
	    # getting matched pane content from read_pane function
	    set matched_pane [read_pane];
	    
	    if { $matched_pane eq "" } {
	        puts "there is problem in latex file."
	        return
	    }
	    
	    
	     # Locate the first occurrence of \putcomment[T, B, M, C]
	    set start_index [find_first_match_index $matched_pane "\\putcomment$selected_position"]
	    if {$start_index == -1} return;
	    
	    # Extract the substring from that position
    	    set sub_input [string range $matched_pane $start_index end]
    	    
    	    # Find the first occurrence of \nextcommandmarker after \putcomment
	    set end_index [find_first_match_index $sub_input "\\nextcommandmarker"]
	    if {$end_index == -1} return;
	    
	    # Extract only up to the first \nextcommandmarker
    	    set match_part [string range $sub_input 0 [expr {$end_index - 1}]]
    	    # Replace old_comment with new_comment i.e.
	    # old_comment = \putcommentT{ Hello World}
	    # new_comment = \putCommentT{ Hi autog}
	    set modifiedContent [string replace $matched_pane $start_index [expr {$start_index + $end_index}] "\\putcomment$selected_position\{$new_comment\}\\"]
	    
	    # Replace the matched pane content with the modified one in the entire file
	    set modifiedFileContent [string map [list $matched_pane $modifiedContent] $fileContent] 
	    # Open the file in write mode and write the modified content back
	    write_to_file $main_file $modifiedFileContent;
	    puts "Comment updated successfully."

	    # Compile the tex file into PDF
	    update_ui ;# Function call: update_ui 
	    bind .right_comment.text <Shift-Tab> {focus -force [tk_focusPrev .right_comment.text]}  ; # shift tab to comment box  

	    
	}
	
	
	
	
	# Function to reset the timer
	proc add_comment_timer {} {
	    global has_unsaved_changes   ;# Access global variables
	    set has_unsaved_changes "true" ;# update the variable
	    
	    set new_comment [.right_comment.text get 1.0 end-1c]
	    
	    after cancel $::comment_timer_id  ; # Cancel any existing timer
	    



	    set ::comment_timer_id [after 750 [list functions::add_comment $new_comment]]  ; # Set a new timer for 0.750 seconds
	   
	}
	
	
	
	
	

	
	proc compare_files {file1 file2} {
	    if {[catch {exec diff $file1 $file2} result]} {
		return "Yes"  ;# Files are different
	    } else {
		return "No"   ;# Files are identical
	    }
	}
	
	
	
	
	
	proc save_changes {} {
	    # Declaring global variables
	    global has_unsaved_changes curr_dir
	    
	    #update the original file, if we have unsaved changes
	    if { $has_unsaved_changes eq "true" } {
		 set present_dir [pwd]
		 cd $curr_dir
		 set file1 [.top.id_combo get].tex
		 set result [compare_files $file1 main.tex]
		 if { $result eq "Yes" } {
		     exec cp main.tex $file1
		 } 
		 cd $present_dir
		 set has_unsaved_changes "false"
	    }
	}
	
	
	proc showError { } {
	    global error_message;
	    if { $error_message eq "" } return ;
	    set filename [.top.id_combo get].tex
	    
	    set message "Compile command: \npdflatex -file-line-error -interaction=nonstopmode -output-directory=build $filename \n\n Errors: \n $error_message"
	    tk_messageBox -message "$message" -icon error -title "Errors";

	}
	
	
	
	
	# function to update pane
	proc update_pane {} {
	    global main_file selected_pane;

	    # Get the max pane number
	    set max_panes [count_panes $main_file]

	    # Generate pane numbers from 1 to max_panes
	    set pane_values [generate_pane_list $max_panes]

	    # Check if the combobox already exists, and update it
	    if {[winfo exists .top.panel_combo]} {
		.top.panel_combo configure -values $pane_values
	    } else {
		ttk::combobox .top.panel_combo -values $pane_values -font myFont
	    }
	    if { [llength $pane_values] == 1} {
		set selected_pane [lindex $pane_values 0];
	    }
	    
	}
	
	
	proc update_widget {tex_ids current_index} {
	puts "inside udpate_widget";
		set file_name [lindex $tex_ids $current_index] 	;#get the name of the file from the list
		puts "insde udpate_wid: $file_name";
		.top.id_combo set $file_name 		;#update the value of ID field
		 create_main                            ; # writting new file to main.tex
	         update_pane                              ; # function call
		 update_comment                            ; # function call
		 update_marks                              ; # function call
		 
		# Check if 'Previous' should be disabled (if at index 0)
		if {$current_index == 0} {
		    .nav.prev configure -state disabled
		} else {
		    .nav.prev configure -state normal
		}
		
		# Check if 'Next' should be disabled (if at last index)
		if {$current_index == [expr {[llength $tex_ids] - 1}]} {
		    .nav.next configure -state disabled
		} else {
		    .nav.next configure -state normal
		}
	}
	
	proc is_error { } {
	    global error_message;
	    if { $error_message ne "" } {
		 tk_messageBox -message "Please fix all errors before proceding" -icon error -title "Error";
		 return "true";
	    }
	    return "false";
	}
	
	
	proc previous_tex {} {
	    # Declaring global variables
	    global tex_ids current_index  curr_dir has_unsaved_changes
	    
	    # if any error, do not allow moving backward
	    if { [is_error] eq "true" } return;
	    
	    #save_changes => copy main.tex to curr_file.tex
	    save_changes ;#function call
	    x
	    # Get the current time in seconds
	    set current_time [clock seconds]
	    
	    # Make sure index is within the range
	    if {$current_index > 0 } {
		# decrement index by 1
		incr current_index -1			

		#update widget
		update_widget $tex_ids $current_index
		
		# udpate ui
		after 1 functions::update_ui	;# function call
		    
	    }
	    
	    #update the value 
	    set has_unsaved_changes "false"
	}
	
	
	
	
	
	# Open tex
	proc open_tex { } {
	    global curr_dir
	    
	    set tex_file_name [.top.id_combo get]
	    set tex_file_path "$curr_dir/$tex_file_name.tex"
	    
	    if {[file exists $tex_file_path]} {
		exec xdg-open $tex_file_path &  ;# For Linux
	    } else {
                tk_messageBox -message "File not found: $tex_file_path" -icon error -title "Error"
	    }
	}
	
	
	
	
	
	# Preview button functionality
	proc preview_tex {} {
	    # Declaring global variables
	    global curr_dir 

            # IF preview is already availabe, return
	    if {![catch {exec pgrep -a evince} result]} {
		if {[string match "*main.pdf*" $result]} {
		    puts "Preview is already available";
		    return
		}
	    } 
		
	    # Function call: Compile .tex into .pdf
	    convert_tex_to_pdf

	    # Get generated PDF file
	    set pdf_file "$curr_dir/build/main.pdf"
	    after 500 [list functions::check_pdf_generation $pdf_file];
	}
	
	
	
	
	
	
	proc next_tex {} {
	    # Declaring global variables
	    global tex_ids current_index  has_unsaved_changes curr_dir
	    
		    
	    # if any error, do not allow moving backward
	    if { [is_error] eq "true" } return;
	    
	    #save_changes => copy main.tex to curr_file.tex
	    save_changes ;#function call
	    
	    # Get the current time in seconds
	    set current_time [clock seconds]
	    
	    # Make sure index is within the range
	    if {$current_index < [expr {[llength $tex_ids] - 1}] } {
		# increment index by +1
		incr current_index 1;
		
		#update widget
		update_widget $tex_ids $current_index
		
		# udpate ui
		after 1 functions::update_ui	;# function call
	    }
	    
	    #update the value 
	    set has_unsaved_changes "false"
	}
	
	
	
	
	
	# read content from file
	proc read_from_file { filename } {
	    set fp [open $filename "r"];
	    set fileContent [read $fp];
	    close $fp;
	    
	    return $fileContent;
	}

	# write content to file
	proc write_to_file { filename modifiedContent} {
	    set fp [open $filename "w"]
	    puts -nonewline $fp $modifiedContent
	    close $fp;
	}
	
	# find index of first occurence of "searchString" in "fileContent"
	proc find_first_match_index { fileContent  searchString } {
	    set start_index [string first $searchString $fileContent]
	    if { $start_index == -1 } {
		puts "No match found for: $searchString";
		return -1;
	    }
	    return $start_index;
	}
		
		
	   
	proc run_pdflatex { main_tex } {
	    global curr_dir error_message;
	    
	    # reset the error_message
	    set error_message "";
	    
	    # Store the path to pwd
	    set present_dir [pwd]
	    
	    # Change directory to curr_dir and compile.tex file asynchronously
	    cd $curr_dir
	    
	    
	     # Use catch to handle errors safely
	    if { [catch {exec pdflatex -file-line-error -interaction=nonstopmode -output-directory=build $main_tex > /dev/null &} result] } {
		set error_message $result;
		cd $present_dir
		return;
	    } 
	    
	    # check for errors in log file
	    after 500 functions::check_For_Error_In_Log_File
	    
	    #change directory back to present_dir
	    cd $present_dir
	}





	proc check_For_Error_In_Log_File { } {
	    global curr_dir error_message

	    # Store the path to pwd
	    set present_dir [pwd]
	    
	    # Change directory to curr_dir and compile .tex file asynchronously
	    cd $curr_dir
	    
	    #open the log file and perform reading
	    set logContent [read_from_file "build/main.log"];
	    
	    # Initialize variables
	    set error_message ""
	    set first_occurrence true
	    
	    # Process each line
	    foreach line [split $logContent "\n"] {
		# Check for occurrences of "./main.tex" or lines starting with "!"
		if {[string match "*./main.tex*" $line]} {
		    if {$first_occurrence} {
		        # Ignore the first occurrence of "./main.tex"
		        set first_occurrence false
		    } else {
		        # Collect subsequent occurrences of "./main.tex"
		        append error_message "$line\n"
		    }
		} elseif {[string match "!*" $line]} {
		    # Collect all lines starting with "!"
		    append error_message "$line\n"
		}
	    }
	    
	    # Update UI and handle errors
	    if {$error_message != ""} {
		enable_SeeErros_Button ;# function call
		cd $present_dir
		return
	    } else {
	       disable_SeeErrors_Button ;# function call
	    }
	    
	    # Change directory back to present_dir
	    cd $present_dir
	}
	
	
	
	proc enable_SeeErros_Button { } {
	    # Configure the button
	    .left_comment.myButton1 configure -fg red -activeforeground red -state normal
	}

	proc disable_SeeErrors_Button { } {
	    # Configure the button
	    .left_comment.myButton1 configure -fg black -activeforeground black -state disabled
	}
	
	
	
	
	
	
	# Function to handle selection change
	proc on_combobox_select {} {
	    global current_index tex_ids;

	    # Get selected value from the combobox
	    set selected_id [.top.id_combo get]

	    # Save current page status before switching
	    save_current_status

	    # Find the index of the selected item
	    set index [lsearch -exact $tex_ids $selected_id]
	    
	    if {$index != -1} {
		set current_index $index
		go_to_page $selected_id  ;# Navigate to the selected page
	    }
	    
	}
	
	
	proc save_current_status {} {
	    # Declaring global variables
	    global  has_unsaved_changes curr_dir current_file;
	    
	    if { $has_unsaved_changes eq "true" } {
		set present_dir [pwd]
		cd $curr_dir
		set file1 "$current_file.tex"
		set result [compare_files $file1 main.tex]
		if { $result eq "Yes" } {
		    exec cp main.tex $file1
		}
		cd $present_dir
	    }
	    
	}
	
	
	
	
	
	# Function to navigate to the selected page
	proc go_to_page {page_id} {
	     # Declaring global variables
	    global tex_ids current_index  has_unsaved_changes curr_dir; 
	     # Get the current time in seconds
	    set current_time [clock seconds]
	    
	    # Make sure index is within the range
	    if {$current_index < [expr {[llength $tex_ids] - 1}] } {
		
		set file_name [lindex $tex_ids $current_index] 	;#get the name of the file from the list
		.top.id_combo set $file_name 			;#update the value of ID field
		create_main                                    ; # writting new file to main.tex
	        update_pane                                    ; # function call
		update_comment                            ; # function call
		update_marks                              ; # function call
		
		# Check if 'Previous' should be disabled (if at index 0)
		if {$current_index == 0} {
		    .nav.prev configure -state disabled
		} else {
		    .nav.prev configure -state normal
		}
		# Check if 'Next' should be disabled (if at last index)
		if {$current_index == [expr {[llength $tex_ids] - 1}]} {
		    .nav.next configure -state disabled
		} else {
		    .nav.next configure -state normal
		}
		
		#updating UI
		update_ui					;# function call: update_ui
		    
	    }
	    
	    
	    #update the value 
	    set has_unsaved_changes "false"
	}
	
	
}
	
	

# Provide the package name and version
package provide functions 1.0
