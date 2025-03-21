package require Tk
source /usr/share/tcltk/tk8.6/ttk/ttk.tcl



set current_dir ""
# Function to select a folder
proc select_folder {} {
    global current_dir  ;
    set current_dir [tk_chooseDirectory -title "Select project Folder"]
    
    if {$current_dir ne ""} {
        .middle.loc_entry delete 0 end
        .middle.loc_entry insert 0 $current_dir
        load_modules $current_dir
    }
}

# Function to read folder names from .SubModuleList.csv and update dropdown
proc load_modules {folder} {
    set file_path "$folder/.SubModuleList.csv"
    if {![file exists $file_path]} {
        tk_messageBox -message "Error: .SubModuleList.csv not found!" -icon error
        return
    }

    set fp [open $file_path r]
    set modules [split [read $fp] "\n"]
    close $fp

    # Remove empty entries and update dropdown
    set module_list [list]
    foreach module $modules {
        if {[string trim $module] ne ""} {
            lappend module_list $module
        }
    }

    # Update the dropdown menu and set the first value as default
    .middle.module_combo configure -values $module_list -state normal
    .middle.module_combo set [lindex $module_list 0]  ;# Set first value as default
    .right.start_button configure -state normal
}

# Function to launch the module window
proc open_module_window {} {
    # Close the main index window
    global current_dir  ;
    set module_folder "[.middle.module_combo get]"
    destroy .
    exec wish module_window.tcl "$current_dir" "$module_folder" &
}

# Title and Geometry
wm title . "aut0G"
wm geometry . 550x100

# Main Frame (Contains Left, Middle, Right Frames)
frame .main -padx 5 -pady 5
grid .main -row 0 -column 0 -sticky news

# Configure main window to expand properly
# grid rowconfigure . 0 -weight 1
grid columnconfigure . 1 -weight 1

# Create Frames
frame .left -padx 2 -pady 0
frame .middle -padx 2 -pady 0
frame .right -padx 2 -pady 0

# Place Frames inside Main Frame
grid .left -row 0 -column 0 -sticky w
grid .middle -row 0 -column 1 -sticky ew
grid .right -row 0 -column 2 -sticky e

# Make Middle Frame Expandable
grid columnconfigure .main 1 -weight 1

# Labels in Left Frame
font create myFont -family "Arial" -size 11 -weight bold
label .left.local_label -text "Project Location" -font myFont
label .left.module_label -text "Select Module" -font myFont
grid .left.local_label -row 0 -column 0 -sticky w -padx 5 -pady {0 10}
grid .left.module_label -row 1 -column 0 -sticky w -padx 5 -pady {10 10}

# Entry & ComboBox in Middle Frame
entry .middle.loc_entry -width 30 -font {Arial 12 normal}
ttk::combobox .middle.module_combo -width 28 -state disabled -font {Arial 12 normal}
grid .middle.loc_entry -row 0 -column 0 -padx 5 -pady {0 10} -sticky ew
grid .middle.module_combo -row 1 -column 0 -padx 5 -pady {2 10} -sticky ew

# Make Middle Column Expandable
grid columnconfigure .middle 0 -weight 1

# Buttons in Right Frame
button .right.select_project -text "Select Project" -command select_folder -font myFont
button .right.start_button -text "Start/Resume" -state disabled -command open_module_window -font myFont
grid .right.select_project -row 0 -column 0 -padx 2 -pady {0 10} -sticky e
grid .right.start_button -row 1 -column 0 -padx 2 -pady {2 10} -sticky e




# GUI Elements
#font create myFont -family Arial -size 12 -weight bold
# font create myFont -family "Handwritten Look" -size 11 -weight bold
# frame .top -padx 5 -pady 5
# label .top.loc_label -text "Project Location" -font myFont
# entry .top.loc_entry -width 30 -font {Arial 12 normal }
# button .top.select_project -text "Select Project" -command select_folder -font myFont
# grid .top.loc_label -row 0 -column 0
# grid .top.loc_entry -row 0 -column 1
# grid .top.select_project -row 0 -column 2
# pack .top -in .main -fill x
# pack .top.loc_label .top.loc_entry .top.select_project -side left -padx 5 -fill x -expand 1

# frame .bottom -padx 10 -pady 5
# label .bottom.module_label -text "Select Module" -font myFont
# ttk::combobox .bottom.module_combo -width 28 -state disabled -font {Arial 12 normal}
# button .bottom.start_button -text "Start/Resume" -state disabled -command open_module_window -font myFont
# grid .bottom.module_label -row 0 -column 0 -padx {5 16}
# grid .bottom.module_combo -row 0 -column 1
# grid .bottom.start_button -row 0 -column 2
# pack .bottom -in .main -fill x
# pack .bottom.module_label .bottom.module_combo .bottom.start_button -side left -padx 5 -fill x -expand 1

# Pack main frames after defining all elements
# pack .top .bottom -side top -fill x

# Run GUI event loop
if {[info exists tk_version]} {
    vwait forever
}
