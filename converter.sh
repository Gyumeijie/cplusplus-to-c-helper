#!/bin/bash
# This script is used for facilitating the convertion of header file 
# from c++ to c with some predefined structure. And the script can divided 
# into two parts, the first part is to extract particular element based on 
# their syntactic structure; and the second part is to generating wanted code
# and structure.

if [[ $# -lt 1 ]];
then
   echo "usage: converter.sh cplusplus_header_file"
   exit 1
fi

#change the suffix of cplusplus header to .H
cplusplus_header=$1
prefix=${cplusplus_header%.*}
suffix=${cplusplus_header#*.}
if [[ $suffix == "h" ]];
then
    if [ -e ${prefix}.H ];
    then
        echo "Input cplusplus header(.H)"
        exit 1
    fi

    cplusplus_header=${prefix}.H
    mv ${prefix}.h ${prefix}.H
fi

if [ ! -e ${cplusplus_header} ];
then
    echo "File named ${cplusplus_header} does't exist"
    exit 1
fi

rm -f hfile ovfile cvfile cffile vffile omfile cfile cmfile ccmfile omdfile \
    cfdfile vfdfile fnsfile

touch hfile ovfile cvfile cffile vffile omfile cfile cmfile ccmfile omdfile \
    cfdfile vfdfile fnsfile

###
### format the cplusplus header file
###
sed 's/^[\t ]\+//g' ${cplusplus_header} > formatted_file 

# escape all double quotes to prevent unterminal string error in awk
sed -i 's/"/\\"/g' formatted_file 

# insert void to () in a function header which takes no arguments, but in order
# consistent process later, doing so is deserved.
sed -i 's/()/(void)/g' formatted_file 

# normalize pointer variable declaration, eg "int** i;" will be transformed
# to "int **i;"
sed -i 's/\([a-zA-Z_]\+\)\(\**\) \([a-zA-Z_]\+\);/\1 \2\3;/g' formatted_file



###
###extract the class itself name and parent name if exist
###
awk_stdout=$(awk '
   # the class has parent
   /^class/ && /\:/{
     gsub(/(class|\:|public|protected|\{)/, " ")
     split($0, ary, " ")
     print ary[1]"/"ary[2]
     exit 0 
   }
   # the class has no parent
   /^class/ {
     gsub(/(class|\:|public|protected|\{)/, "")
     split($0, ary, " ")
     print ary[1]"/"
     exit 0
   }
 ' formatted_file)

self=${awk_stdout%/*}
parent=${awk_stdout#*/}

if [[ ${#parent} == 0 ]];
then
    parent="Object";
fi

self_class=${self}Class
parent_class=${parent}Class
uppercase_parent=$(echo $parent | tr 'a-z' 'A-Z')
uppercase_self=$(echo $self | tr 'a-z' 'A-Z')
lowercase_self=$(echo $self | tr 'A-Z' 'a-z')



###
### extract parts to corresponding files for later use
###
awk '

 function clear_comments() {
    system("rm "  comments  " && "  "touch " comments);
 }

 function write_comments_to(file_to_write, is_multiline_comment){

    if (system("test -s "  comments) == 0){
        
        if (is_multiline_comment) {
            system("echo "  "\/\**"  " >> " file_to_write );
            system("cat "  comments  " >> "  file_to_write);
            # "*/" should has one space indentation
            system("echo " "\" "  "*/"  "\" " " >> "  file_to_write);

        } else {
            system("cat "  comments  " >> "  file_to_write);
        }

        clear_comments();
     }
 }
 
 function get_access_constrol_description(access_control){
 
    if (access_control == 0) ac = "private";
    else if (access_control == 1) ac = "protected";
    else ac = "public";

    return ac;
 }

 BEGIN {
    comment_for_class = 1;
    comment_for_copyright = 1;

    # count function number
    virtual_func_num = 0;
    object_method_num = 0;
    class_func_num = 0;
    
    # comment style
    is_multiline_comment = 0;

    # private is defalut, private:0, protected:1, public:2.
    access_control = 0;
 }

 # extract comments // style
 /^\/\//{
    if (comment_for_copyright != 1) {
        system("echo " "\""  $0  "\"" " >> " comments);
        is_multiline_comment = 0;
    } else {
        system("echo " "\""  $0  "\"" " >> " copyright);
    }
    next
 }

 # sigle-line /**/ style comment
 /^\/\*/ && /\*\//{
    system("echo " "\""  $0  "\"" " >> " comments);
    is_multiline_comment = 0;
    next
 }

 # multi-line /**/ style comment start
 /^\/\*/{
    is_multiline_comment = 1;
    next
 }

 # comments enclosed in  * 
 /^\*[^\/]+/{
    if (comment_for_class != 1) {
      # here comments file serves as temprary file holding comments which
      # will be tackled immediately atfer.
      system("echo " "\" " $0  "\"" " >> " comments);
    } else {
      system("echo " "\" "  $0  "\"" " >> " class_comments);
    }
    next
 }

 # /**/ style comment end
 /^\*\//{
   if (comment_for_class == 1) comment_for_class = 0;

   next
 }

 # tackle header which includes inline function definiton
 /\#include/ && /_inl.h/{
     next
 }

 # extract header 
 /\#include/{
    system("echo " "\""  $0  "\"" " >> " includes);
    comment_for_copyright = 0;
    next
 }

 # extract object variables
 !/static/ && /[a-zA-Z_ ]+ \**[a-zA-Z_]+;/{
    write_comments_to(object_variables, is_multiline_comment);

    # with 4 spaces indentation
    system("echo " "\"    "  $0  "\"" " >> " object_variables);
    next
 }

 # extract class variables
 /static/ && /[a-zA-Z_ ]+ \**[a-zA-Z_]+;/{
    write_comments_to(class_variables, is_multiline_comment);

    ac = get_access_constrol_description(access_control);

    system("echo " "\"" ac  "\" "  "\""  $0  "\""  " >> " class_variables);

    # add a blank line between two class variable decalration
    system("echo " " >> " class_variables);

    next 
 }
  
 # extract static functions
 /static/{

    class_func_num++;

    write_comments_to(class_funcs_decl, is_multiline_comment);
    
    ac = get_access_constrol_description(access_control);

    # class_funcs_decl used in header file and class_funcs used in source file
    system("echo " "\"" ac  "\" "  "\""  $0  "\""  " >> " class_funcs_decl);
    system("echo "  ">> " class_funcs_decl);

    system("echo " "\"" ac  "\" "  "\""  $0  "\""  " >> " class_funcs);
    #system("echo FUNCTION_BODY_HERE_" class_func_num " >> " class_funcs);
    system("echo " " >> " class_funcs);

    next
 }
 
 # extract virtual functions
 /virtual/{
    virtual_func_num++;

    write_comments_to(virtual_funcs_decl, is_multiline_comment);

    system("echo " "\"    "  $0  "\"" " >> " virtual_funcs);

    system("echo " "\"    "  $0  "\"" " >> " virtual_funcs_decl);
    system("echo " " >> " virtual_funcs_decl);
    next
 }

 # extract normal object methods, not include copy, constructor, destructor
 # funcnton
 /[a-zA-Z_] *\(/ && $0 !~ class_name{
    object_method_num++;

    write_comments_to(object_methods_decl, is_multiline_comment);

    system("echo " "\"    "  $0  "\"" " >> " object_methods);

    system("echo " "\"    "  $0  "\"" " >> " object_methods_decl);
    system("echo " " >> " object_methods_decl);

    next
  }
 

 # private access control
 /private *:/{
     access_control = 0;
     next
  }

 # protected access control
 /protected *:/{
     access_control = 1;
     next
  }
 
 # public access control
 /public *:/{
     access_control = 2;
     next
  }

  {
      clear_comments();
  }
 END{
    system("echo V_FUNCTION_NUMBER=" virtual_func_num " >> " func_num_statics);
    system("echo O_METHOD_NUMBER=" object_method_num " >> " func_num_statics);
    system("echo C_FUNCTION_NUMBER=" class_func_num " >> " func_num_statics);
 }

' includes=hfile object_variables=ovfile  class_funcs=cffile \
  virtual_funcs=vffile class_variables=cvfile object_methods=omfile \
  copyright=cfile comments=cmfile class_comments=ccmfile \
  class_funcs_decl=cfdfile virtual_funcs_decl=vfdfile \
  object_methods_decl=omdfile func_num_statics=fnsfile\
  class_name="${self}"  formatted_file \
 

# we can safely remove formatted_file 
rm -f formatted_file

#set output c header name
c_header=${self}.h
echo "c_header is $c_header"

# save the original stdout for later restoration
exec  {saved_stdout}>&1
exec {c_header_fd}>${c_header} 1>&${c_header_fd}



###
### emit copyright info
###
cat cfile




echo -e "\n"
###
###  emit header protection macros 
###
echo "#ifndef ${uppercase_self}_H"
echo "#define ${uppercase_self}_H"




echo -e "\n"
###
### emit included header
###
cat hfile
echo "#include \"../Qom/object.h\""




echo -e "\n"
###
### emit class comments
###
if [ -s ccmfile ];
then
    echo "/*"
    cat ccmfile
    echo " */"
fi

echo "#define TYPE_${uppercase_self} \"${lowercase_self}\""
echo ""
echo "void ${lowercase_self}_register(void);"



###
### 
###
if [ -s cfdfile ];
then
   echo -e "\n"
   echo "///////////////////////////////////////////////////////////////////////////////"
   echo "//"
   echo "//                            class methods declaration"
   echo "//"
   echo "///////////////////////////////////////////////////////////////////////////////"
   echo ""
   # tackle file declaration according access control keyword: if it is "private"
   # or "protected" then just remove keyword and leave "static" as it is.Otherwise
   # remove both access control keyword "public" and "static".
   #TODO maybe there are more case to be dealt with
   sed -i \
       -e 's/private \(.*\)/\1/g' \
       -e 's/protected \(.*\)/\1/g' \
       -e 's/public static \(.*\)/\1/g' \
       -e 's/public inline static \(.*\)/inline \1/g'\
       -e "s/\([a-zA-Z_]\+\)(/${self}_\1(/g" cfdfile cffile

   
   cat cfdfile
fi




echo -e "\n"
###
### define the object struct
###
echo "///////////////////////////////////////////////////////////////////////////////"
echo "//"
echo "//                            class and struct"
echo "//"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""
echo "typedef struct $self {"
echo -e "    $parent parent;\n"
if [ -s ovfile ];
then
    cat ovfile
fi
echo "} $self;"




echo -e "\n"
###
### define the class struct
###
echo "typedef struct $self_class {"
echo -e "    $parent_class parent_class;\n"

# tackle const pure virtual functon
# tackle non-const pure virtual function
# tackle const function
# tackle non-const function
# tackle void: (void)--->([const]Object *obj, void)--->([const]Object *obj)
sed -i \
    -e 's/\([a-zA-Z_]\+\)\(\**\) \([a-zA-Z_]\+\)(\(.*\) const = 0;/\1\2 (*\3)(const Object *obj, \4;/g' \
    -e 's/\([a-zA-Z_]\+\)\(\**\) \([a-zA-Z_]\+\)(\(.*\) = 0;/\1\2 (*\3)(const Object *obj, \4;/g' \
    -e 's/\([a-zA-Z_]\+\)\(\**\) \([a-zA-Z_]\+\)(\(.*\) const;/\1\2 (*\3)(const Object *obj, \4;/g' \
    -e 's/\([a-zA-Z_]\+\)\(\**\) \([a-zA-Z_]\+\)(/\1\2 (*\3)(Object *obj, /g'  \
    -e 's/, \+void)/)/g' vffile omfile

# tackle non virtual object method: remove constructor and destructor
sed -i -e "/${self}(/d" -e '/^$/d' omfile

# tackle virtual object methods: remove virtual keyword
sed -i 's/virtual \+//g' vffile

cat omfile
echo ""
cat vffile
echo "} $self_class;"




echo -e "\n"
###
### emit the macros
###
echo "#define ${uppercase_self}_GET_CLASS(obj) \\
        OBJECT_GET_CLASS(${self_class}, obj, TYPE_${uppercase_self})" 

echo "#define ${uppercase_self}_CLASS(klass) \\
        OBJECT_CLASS_CHECK(${self_class}, klass, TYPE_${uppercase_self})"

echo "#define ${uppercase_self}(obj) \\
        OBJECT_CHECK(${self}, obj, TYPE_${uppercase_self})"




echo -e "\n"
###
###  postprocess
###
echo "#endif"
dos2unix  ${c_header}  >&/dev/null


### restore stdout
exec 1>&${saved_stdout}


####TODO
if [ ! -e ${self}.cpp ];
then
    if [ -e ${self}_inl.h ];
    then
        echo "touch a blank ${self}.cpp"
        touch ${self}.cpp
    else
        echo "Waning: not process ${self}.cpp"
        exit 0
    fi
fi


# keep the header part of the source file, this method presume that the source
# file has the following layout:
# 1. copyright information
# 2. include headers
# 3. optional static data initialization
# 4. methods definition
# the header part is 1, 2 and 3.
rm -f shfile
touch shfile
cplusplus_source_file=${self}.cpp
awk '
  # if reach the first function definiton then we quit
  # here use .* to match cplusplus method name instead of [a-zA-Z_]+,for
  # .* is more accurate.
  /::.*\(/{
     exit 0
  }
  
  {
     system("echo " "\""  $0  "\"" " >> " source_file_header_part);
  }
' class_name=${self} source_file_header_part=shfile $cplusplus_source_file 

# add double quotes for #include marcos in shfile
# #include "../GeneralInclude/CompilerSwitches.h^M"
# to remove ^M we need doing the following convertion
dos2unix shfile>&/dev/null
sed -i 's/\(#include\) *\(.*\)/\1 \"\2\"/g' shfile

# file includes cplusplus source file and inline header if exists. 
touch mixed_file
if [ -e ${self}_inl.h ];
then
    cat ${self}_inl.h ${cplusplus_source_file} > mixed_file
else  
    cat ${cplusplus_source_file} > mixed_file
fi



###
### 
###
c_source_file=${self}.c
rm -f ${c_source_file}
touch ${c_source_file}

exec {saved_stdout}>&1
exec {c_source_file_fd}>${c_source_file} 1>&${c_source_file_fd}

has_class_var_init=$(awk '
                    !/\/\// && !/\*/ && /=/{
                         print "yes"
                         exit 0
                    }' shfile)


# if there are class variable initialization, then extract them and
# add corresponding initial value to the cvfile
if [[  $has_class_var_init == "yes" ]];
then
    rm -f cvilist
    touch cvilist

    # extract class variable initialization to cvilist, in the form of 
    # "varname=init_valule"
    sed -n 's/.*::\([a-zA-Z_]\+\) *= *\([0-9a-zA-Z_]\+\) *;/\1=\2/gp' shfile > cvilist
    ####TODO why need dos2unix
    ####without doing conversion ";varname = init_value"
    ####"varname = init_value;" is the answer
    dos2unix cvilist>&/dev/null

    # add initial value of class variable to cvfile
    while read line;
    do
        varname=${line%=*} 
        # varname=$(sed -n "s/\(.*\)=\(.*\)/\2/p <<<$line")

        init_value=${line#*=}
        # init_value=$(sed -n "s/$varname=\(.*\)/\1/gp" cvilist) 

        sed -i "s/$varname;/$varname = $init_value;/g" cvfile
    done <cvilist
fi


sed -i \
    -e 's/private \(.*\)/\1/g' \
    -e 's/protected static \(.*\)/\1/g' \
    -e 's/public static \(.*\)/\1/g' cvfile

# header part of source file
sed -i '/::/d' shfile
cat shfile


if [ -s cvfile ];
then
    echo "///////////////////////////////////////////////////////////////////////////////"
    echo "//"
    echo "//                            class data"
    echo "//"
    echo "///////////////////////////////////////////////////////////////////////////////"
    echo ""
    cat cvfile
fi


function construct_pattern(){
   if [ $# -lt 2 ];
   then
       echo "construct_pattern need two parameters"
       exit 1
   fi 

   echo "$1::$2 *\("
}

# extact function body of a given name function
####TODO awk ' 'x should have a space after the closing'
function extract_function_body(){
   rm -f fbfile
   touch fbfile
   awk '
       BEGIN{
           is_function_body = 0;
       }

       /^\/\//{
           next 
       }

       $0~pattern{ 
           system("echo " "\"{"  "\"" " >> " func_body);
           is_function_body = 1; 
           next
       }

       # assume the end of function "}" is at the begin of line
       /^\}/ {
           if (is_function_body == 0){
               next
           }else{ 
              system("echo " "\"}"  "\"" " >> " func_body);
              exit 0
           }
        }

        {
            if (is_function_body == 1){ 
                system("echo " "\""  $0  "\"" " >> " func_body);
            }
            next
        }

        ' pattern="$1" func_body=fbfile mixed_file 
}

function is_duplicate(){
   old_line_num=$(cat $1 | wc -l)
   new_line_num=$(cat $1 | sort | uniq |  wc -l)

   if [ $old_line_num -ne $new_line_num ];
   then
       #can't return true or false, numeric argument required
       return 0;
   else
       return 1;
   fi
}

###
### process class function 
### 
#class_func_num=$(sed -n 's/C_FUNCTION_NUMBER=\([0-9]\+\)/\1/gp' fnsfile)
#echo ${class_func_num}
#i=1
#while [ $i -le $class_func_num ];
#do 
#   
#    let i=i+1;
#done
sed -n 's/[a-zA-Z_\* ]\+ \([a-zA-Z_]\+\)(.*/\1/gp' cffile > cflist
sed -i "s/${self}_\([a-zA-Z_]\+\)/\1/g" cflist

if is_duplicate cflist;
then
    exec 1>&${saved_stdout}
    echo "sorry, there are more than two functions with the same name"
    echo "dupicate files are the following:"
    echo "$(cat cflist | sort | uniq -c | sed '/1/d')"
    exit 1
fi


# remove ; in file including class function declaraton
sed -i 's/;//g' cffile

function append_function_body_to(){
     if [ $# -lt 2 ];
     then
         echo "need two args:$1 list, $2 file"
         exit 1
     fi

    i=1;
    while read line;
    do
        # pattern may contains spaces, so it is necessary to protect it with 
        # double quotes
        extract_function_body "$(construct_pattern ${self} ${line})"
    
        #fb=$(cat fbfile)
        #sed -i "s/$i/$fb/g" cffile
        #
        #sed -i "/FUNCTION_BODY_HERE_$i/a\\$fb" cffile

        #location line-end sign $ is necessary
        #insert_location=$(sed -n "/FUNCTION_BODY_HERE_$i$/=" cffile)
        insert_location=$(sed -n "/$line/=" $2)
        line_num=$(cat fbfile | wc -l) 

        ####TODO very important IFS
        IFS=''
        while read line2;
        do
            ####TODO very important\\$varname
            sed -i "${insert_location}a\\$line2" $2
            let insert_location=insert_location+1
        done < fbfile

        let i=i+1;

    done <$1
}


append_function_body_to cflist  cffile
####TODO here rm cflist

####TODO why need dos2unix
if [ -s cffile ];
then
    echo "///////////////////////////////////////////////////////////////////////////////"
    echo "//"
    echo "//                            class  methods definition"
    echo "//"
    echo "///////////////////////////////////////////////////////////////////////////////"
    echo ""
    cat cffile
fi



###
### non-virtual object methods
###

function produce_function_header(){
    if [ $# -lt 1 ];
    then
       echo "need file"    
       exit 1
    fi

    sed -i \
        -e 's/(\*\([a-zA-Z_]\+\))/\1/g'\
        -e 's/^[\t ]\+//g'\
        -e 's/;//g' $1 
}

function process_object_method(){

    if [ -s $1dfile ];
    then
        rm -f $1list
        touch $1list
        sed -e 's/.*(\*\([a-zA-Z_]\+\)).*/\1/g' $1file > $1list 
        produce_function_header $1file
    
        while read line;
        do
            func_header=$(sed -n "/$line/p" $1file)
            sed -i "s/.*$line(.*;/$func_header/g" $1dfile
        done <$1list
    
        append_function_body_to $1list $1dfile
    
        if [[ $1 == "om" ]];
        then
            kind="non-virtual"
        else
            kind="virtual"
        fi
        echo "///////////////////////////////////////////////////////////////////////////////"
        echo "//"
        echo "//                    ${kind} object methods definition"
        echo "//"
        echo "///////////////////////////////////////////////////////////////////////////////"
        echo ""
        unset kind   

        cat $1dfile
    fi
}

process_object_method "om"
process_object_method "vf"




###
###
###

echo "///////////////////////////////////////////////////////////////////////////////"
echo "//"
echo "//                   object constructor and deconstuctor"
echo "//"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""

echo "static void ${lowercase_self}_instance_init(Object *obj)"
extract_function_body "$(construct_pattern ${self} ${self})"
cat fbfile


extract_function_body "$(construct_pattern ${self} ~${self})"
if [ -s fbfile ];
then
   echo "static void ${lowercase_self}_instance_fininalize(Object *obj)"
   cat fbfile
fi
echo ""

###
###
###
cat omlist vflist > mergedlist
echo "///////////////////////////////////////////////////////////////////////////////"
echo "//"
echo "//                   binding and type register"
echo "//"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""

class_name=$(echo "${self_class}" | tr -d 'a-z' | tr 'A-Z' 'a-z')

# class init
echo "static void ${lowercase_self}_class_init(ObjectClass *oc, void *data)"
echo "{"
echo "    ${self_class} *${class_name} = ${uppercase_self}_Class(oc);"
echo ""

while read line;
do
    echo "    ${class_name}->$line = $line;"
done <mergedlist
rm -f mergedlist

echo "}"

# type infomation
echo ""
echo "static const TypeInfo ${lowercase_self}_type_info = {"
echo "    .name = TYPE_${uppercase_self},"
echo "    .parent = TYPE_${uppercase_parent},"
echo "    .instance_size = sizeof(${self}),"
echo "    .abstract = false,"
echo "    .class_size = sizeof(${self_class}),"
echo "    .instance_init = ${lowercase_self}_instance_init," 
echo "    .class_init = ${lowercase_self}_class_init" 
echo "}"

#type register
echo ""
echo "void ${lowercase_self}_register(void)"
echo "{"
echo "    type_register_static(&${lowercase_self}_type_info);"
echo "}"

#exec 1>&${saved_stdout}
dos2unix ${c_source_file}>&/dev/null


