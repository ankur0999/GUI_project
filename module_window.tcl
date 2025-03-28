package require Tk
# Add the package directory to Tcl's search path
set path [pwd]
lappend auto_path "$path/mypackage"

# load the packages
package require functions

# some global variables defined
set current_folder [lindex $argv 0]  ;# Get current folder from command-line arguments
set module_folder [lindex $argv 1]   ;# Get the module/question name


# Set up the current directory
set curr_dir [file join $current_folder $module_folder]
set main_file "$curr_dir/main.tex"
set current_file ""
set tex_file_sequence "$curr_dir/.TexFileSequence.csv" ;#Absolute path
set last_compile_time 0
set selected_position "T"
set selected_pane ""
set ::comment_timer_id ""
set ::marks_timer_id ""
set has_unsaved_changes "false";
set error_message "";



# tex_ids => list of entries of TexFileSequence.csv file
set tex_ids [functions::load_tex_files $tex_file_sequence];
if { [llength $tex_ids] > 0 } {
    set current_index 0
} else {
   tk_messageBox -message "Present directory doesn't contain any .tex file" -icon error;
   exit 1;
}







# ****************************
# Main Window Setup
# ****************************

# Title and Geometry
wm title . "$module_folder"
wm geometry . 500x227

# Bind the close event: function call to "on_close" function
wm protocol . WM_DELETE_WINDOW functions::on_close

# Main Frame (Holds Everything)
frame .main -padx 2 -pady 2
grid .main -row 0 -column 0 -sticky nsew

# Ensure ".main" expands within the root window
grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1

# Font Creation
font create myFont -family "Helvetica" -size 12 -weight normal
# Create a custom style for the combobox
ttk::style configure Custom.TCombobox -padding {5 5 1 1}



# ****************************
# Top Frame (ID & Panel)
# ****************************

frame .top -padx 2 -pady 2

# Labels & Comboboxes for ID and Panel
label .top.id_label -text "ID" -font myFont
ttk::combobox .top.id_combo -values $tex_ids -font myFont -width 35  -style Custom.TCombobox
.top.id_combo set [lindex $tex_ids 0] ;# Set first file name as default value

# Bind Enter key to trigger filtering while typing
bind .top.id_combo <KeyRelease> {functions::filter_combobox "type"}

# Manually trigger dropdown when clicking on the arrow button
bind .top.id_combo <ButtonPress-1> {
    if {[winfo pointerx .] > [expr {[winfo rootx .top.id_combo] + [winfo width .top.id_combo] - 20}]} {
        event generate .top.id_combo <Down>
        
        functions::filter_combobox "click"
    }
}


#**************************************************************
# create main.tex
functions::create_main 


# Get the max pane number
set max_panes [functions::count_panes $main_file]


# Generate pane numbers from 1 to max_panes
set pane_values [functions::generate_pane_list $max_panes]
#**************************************************************

label .top.panel_label -text "Pane" -font myFont
ttk::combobox .top.panel_combo -values $pane_values -textvariable selected_pane -font myFont -style Custom.TCombobox





# Positioning Components
grid .top.id_label -row 0 -column 0 -sticky w -padx {3 80}
grid .top.id_combo -row 0 -column 1 -sticky ew -padx 3
grid .top.panel_label -row 0 -column 2 -sticky w -padx 3
grid .top.panel_combo -row 0 -column 3 -sticky ew -padx 3

# Ensure Combo Boxes Expand in Width
grid columnconfigure .top 1 -weight 1
grid columnconfigure .top 3 -weight 1

# Attach Top Frame to Main Layout
grid .top -in .main -row 0 -column 0 -sticky new
grid rowconfigure .main 0 -weight 0
grid columnconfigure .main 0 -weight 1





# ****************************
# Marks Frame (Marks Entry)
# ****************************

frame .marks -padx 2 -pady 2

# Marks Label & Entry
label .marks.label -text "Marks" -font myFont -state disabled
entry .marks.entry -font myFont

# Set Default Value for Marks Entry
.marks.entry insert 0 0  

# Bind the KeyRelease event to call update_comment_timer when the user types
bind .marks.entry <KeyRelease> {add_marks_timer} ;

# Positioning Components
grid .marks.label -row 0 -column 0 -sticky w -padx {4 52}
grid .marks.entry -row 0 -column 1 -sticky ew -padx 3

# Ensure Entry Expands in Width
grid columnconfigure .marks 1 -weight 1

# Attach Marks Frame to Main Layout
grid .marks -in .main -row 1 -column 0 -sticky new
grid columnconfigure .main 0 -weight 1






# ****************************
# Comment Section
# ****************************

# Comment Frame (Holds Left & Right Comments)
frame .comment -padx 2 -pady 2 

# Left Comment Frame (Fixed Width, Expands in Height)
frame .left_comment -padx 2 -pady 2 -relief solid 
grid .left_comment -in .comment -row 0 -column 0 -sticky ns

# Ensure Left Comment Grows in Height Only
grid rowconfigure .comment 0 -weight 1
grid columnconfigure .comment 0 -weight 0

# Left Comment Contents
label .left_comment.label -text "Comment" -font myFont 
grid .left_comment.label -row 1 -column 0 -sticky w -padx 3 -pady 2

ttk::combobox .left_comment.dropdown -values {T M B C} -width 5 -textvariable selected_position -font myFont  -style Custom.TCombobox

grid .left_comment.dropdown -row 3 -column 0 -sticky w -padx 3 -pady 2

button .left_comment.myButton1 -text "See Errors" -font myFont -width 7 -height 1 -command functions::showError -state disabled
grid .left_comment.myButton1 -row 4 -column 0 -sticky w -padx 3 -pady 2

# Ensure Space Above & Below the Label Expands
grid rowconfigure .left_comment {0 2} -weight 1
grid rowconfigure .left_comment {1 3 4} -weight 0
grid columnconfigure .left_comment 0 -weight 0


# Right Comment Frame (Expands in Both Width & Height)
frame .right_comment -padx 5 -pady 5 
grid .right_comment -in .comment -row 0 -column 1 -sticky nsew

# Ensure Right Comment Grows Fully
grid columnconfigure .comment 1 -weight 1
grid rowconfigure .comment 0 -weight 1

# Textbox Inside Right Comment (Captures 100% Space)
text .right_comment.text -wrap word -height 5 -width 40 -font myFont
grid .right_comment.text -row 0 -column 0 -sticky nsew
bind .right_comment.text <KeyRelease> {functions::add_comment_timer} 

# Ensure Textbox Expands Fully
grid rowconfigure .right_comment 0 -weight 1
grid columnconfigure .right_comment 0 -weight 1

# Attach Comment Frame to Main Layout
grid .comment -in .main -row 2 -column 0 -sticky nsew
grid columnconfigure .main 0 -weight 1
grid rowconfigure .main 2 -weight 1








# ****************************
# Navigation Section
# ****************************

frame .nav -padx 5 -pady 2 

# Navigation Buttons
button .nav.prev -text "\u2190 Previous" -command functions::previous_tex -font myFont
button .nav.open_tex -text "Open_tex" -command functions::open_tex -font myFont 
button .nav.preview -text "Preview" -command functions::preview_tex -font myFont
button .nav.next -text "Next \u2192" -command functions::next_tex -font myFont

# Position Buttons (Grow in Width, Fixed Height)
grid .nav.prev -row 0 -column 0 -sticky ew -padx 2
grid .nav.open_tex -row 0 -column 1 -sticky ew -padx 2
grid .nav.preview -row 0 -column 2 -sticky ew -padx 2
grid .nav.next -row 0 -column 3 -sticky ew -padx 2

# Ensure All Buttons Expand Equally
grid columnconfigure .nav {0 1 2 3} -weight 1

# Attach Navigation Frame at the Bottom
grid .nav -in .main -row 3 -column 0 -sticky ew 

# Ensure Nav Row Does NOT Expand in Height
grid rowconfigure .main 3 -weight 0
grid columnconfigure .main 0 -weight 1



# Add a trace on selected_pane
trace add variable selected_pane write {functions::on_selected_tab_change pane}

.top.panel_combo insert 0 1 ;#set default vaule for Panel Combo (default: 1)

trace add variable selected_position write {functions::on_selected_tab_change ""};# Trace the variable to call update_comment when it changes


# Bind combobox selection change to event
bind .top.id_combo <<ComboboxSelected>> {functions::on_combobox_select}


# main function
proc main { } {
    global current_index tex_ids
    
    # Preprocessing : function calls                         ; # writting new file to main.tex
    functions::update_pane                                    ; # function call
    functions::update_comment                                 ; # function call
    functions::update_marks                                   ; # function call
    #create_pdf
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

# Function call: main
main;

