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



###############################################################################
#
#                             preprocess 
#
###############################################################################

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
### extract the class itself name and parent name if exist
###

# for the cplusplus souce file only has single inheritance, and the qemu object
# model only support single inheritance in this way (multi inheritance can be
# do by using interfaces in qemu), we here just tackle this case.
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

touch hfile ovfile cvfile cffile vffile omfile cfile cmfile ccmfile omdfile \
    cfdfile vfdfile fnsfile

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
 
# we can safely remove formatted_file.
rm -f formatted_file

# cat the fnsfile to show the number of function 
# cat fnsfile




###############################################################################
#
#                             generate .h file
#
###############################################################################

#set c header name
c_header=${self}.h
echo "c_header is $c_header"

# save the original stdout for later restoration
exec {saved_stdout}>&1
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
###  process class method declaration
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

# tackle non-virtual object method: remove constructor and destructor
# here we just distiguish constructor and destructor between other non-virtual
# object method.
sed -i -e "/${self}(/d" -e '/^$/d' omfile

# tackle virtual object methods: remove virtual keyword.
sed -i 's/virtual \+//g' vffile

echo "typedef struct $self_class {"
echo -e "    $parent_class parent_class;\n"

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
###  postprocess for ${self}.h file
###

echo "#endif"
dos2unix  ${c_header}  >&/dev/null




###############################################################################
#
#                             generate .c file
#
###############################################################################

# check the existence of source file and/or inline header file.
if [ ! -e ${self}.cpp ];
then
    if [ -e ${self}_inl.h ];
    then
        echo "mv ${self}_inl.h to ${self}.cpp"

        # if there is no .cpp file exist, then we treat _inl.h as .cpp file.
        mv ${self}_inl.h ${self}.cpp
        
        # remove header protection macros.
        sed -i \
            -e '/#ifndef/d'\
            -e '/#define/d'\
            -e '/#endif/d' ${self}.cpp
           
        # update file name to ${self}.cpp in copyright information.
        sed -i \
            "s/${self}_inl.h/${self}.c (from ${self}_inl.h file)/g" ${self}.cpp
        
        is_cpp_from_inline="yes"
    else
        echo "Waning: there is no ${self}.cpp and ${self}_inl.h"
        exit 1
    fi
fi





###
### header part of source file
###

# keep the header part of the source file, this method presume that the source
# file has the following layout:
# 1. copyright information
# 2. include headers
# 3. optional static data initialization
# 4. methods definition
# the header part is 1, 2 and 3.
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
# #include "../GeneralInclude/CompilerSwitches.h^M", to remove ^M we need 
# doing the following convertion
dos2unix shfile>&/dev/null

# add double quotes for included file, for process above the double quotes lost.
sed -i 's/\(#include\) *\(.*\)/\1 \"\2\"/g' shfile

# update file name in copyright information 
sed -i "s/${self}.cpp/${self}.c/g" shfile

# file includes cplusplus source file and inline header if exists, mixed file
# mainly contains class data initialization and/or method definition.
touch mixed_file
if [ -e ${self}_inl.h ];
then
    cat ${self}_inl.h ${cplusplus_source_file} > mixed_file
else  
    cat ${cplusplus_source_file} > mixed_file
fi


c_source_file=${self}.c
rm -f ${c_source_file}
touch ${c_source_file}

exec {saved_stdout}>&1
exec {c_source_file_fd}>${c_source_file} 1>&${c_source_file_fd}

# remove the class data initialization in source file, for them lost access
# control information: we have know idea about which data has private, protected
# or public access; and we have cvfile, which includes such information.
sed -i '/::/d' shfile
cat shfile





###
###  process class data 
###

if [ -s cvfile ];
then

    has_class_var_init=$(awk '
                        !/\/\// && !/\*/ && /=/{
                             print "yes"
                             exit 0
                        }' shfile)
    
    
    # if there are class variable initialization, then extract them and
    # add corresponding initial value to the cvfile.
    if [[  $has_class_var_init == "yes" ]];
    then
        rm -f cvilist
        touch cvilist
    
        # extract class variable initialization to cvilist, in the form of 
        # "varname=init_valule".
        sed -n 's/.*::\([a-zA-Z_]\+\) *= *\([0-9a-zA-Z_]\+\) *;/\1=\2/gp' shfile > cvilist
    
        # without doing conversion ";varname = init_value";
        # "varname = init_value;" is the answer.
        dos2unix cvilist>&/dev/null
    
        # add initial value of class variable to cvfile.
        while read line;
        do
            varname=${line%=*} 
            # varname=$(sed -n "s/\(.*\)=\(.*\)/\2/p <<<$line")
    
            init_value=${line#*=}
            # init_value=$(sed -n "s/$varname=\(.*\)/\1/gp" cvilist) 
    
            sed -i "s/$varname;/$varname = $init_value;/g" cvfile
        done < cvilist
    fi
    
    
    sed -i \
        -e 's/private \(.*\)/\1/g' \
        -e 's/protected static \(.*\)/\1/g' \
        -e 's/public static \(.*\)/\1/g' cvfile
    
    
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
function extract_function_body(){

   if [ $# -lt 1 ];
   then
       echo "a function name is required for extracting it's body."
       exit 1
   fi

   # here we don't use echo "" > file to clear the previous content in the file
   # for it will bring an unwanted newline.
   rm -f fbfile
   touch fbfile

   # the main idea is finding the function which matchs a pattern first, then 
   # we output the body to the func_body file, until we meet the function end
   # tag "}".
   awk '
       BEGIN{
           is_function_body = 0;
       }

       /^\/\//{
           next 
       }

       # find the function 
       $0~pattern{ 
           system("echo " "\"{"  "\"" " >> " func_body);
           is_function_body = 1; 
           next
       }

       # assume the end of function "}" is at the begin of line, this can be
       # guaranteed in preprocess phase or we can do ourselves.
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
    
   if [ $# -lt 1 ];
   then
       echo "a file to check duplicate is need."
       exit 1
   fi

   old_line_num=$(cat $1 | wc -l)
   new_line_num=$(cat $1 | sort | uniq |  wc -l)

   if [ $old_line_num -ne $new_line_num ];
   then
       # can't return true or false, numeric argument required
       return 0;
   else
       return 1;
   fi
}





echo -e "\n"
###
### process class function 
### 

# generate a list of class function name prefixed without ${self}_
sed -n 's/[a-zA-Z_\* ]\+ \([a-zA-Z_]\+\)(.*/\1/gp' cffile > cflist
sed -i "s/${self}_\([a-zA-Z_]\+\)/\1/g" cflist

if is_duplicate cflist;
then
    # restore stdout for outputing error message
    exec 1>&${saved_stdout}

    echo "sorry, there are more than two functions with the same name"
    echo "dupicate files are the following:"
    echo "$(cat cflist | sort | uniq -c | sed '/1/d')"
    exit 1
fi


# remove ; in file including class function declaraton
# function_header(); ---> function_header()
sed -i 's/;//g' cffile

function append_function_body_to(){

    if [ $# -lt 2 ];
    then
        echo "need two args:$1 for a list of function name and  $2 for a file"
        echo "including function declarations."
        exit 1
    fi

    # for better understanding, we rename $1 and $2
    func_list_file=$1
    func_decl_file=$2 

    i=1;
    while read func_name_line;
    do
        # pattern may contains spaces, so it is necessary to protect it with 
        # double quotes.
        extract_function_body "$(construct_pattern ${self} ${func_name_line})"
    
        # get the line number where line matchs the function name.
        insert_location=$(sed -n "/$func_name_line/=" ${func_decl_file})

        IFS=''
        # append function body in fbfile line by line below the corresponding
        # function declaration line in func_decl_file.
        while read func_decl_line;
        do
            sed -i "${insert_location}a\\${func_decl_line}" ${func_decl_file}

            # update the next line number to append function body line.
            let insert_location=insert_location+1

        done < fbfile

        # process the next function, according to it's name in func_list_file.
        let i=i+1;

    done < ${func_list_file}
}

append_function_body_to cflist  cffile

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





echo -e "\n"
###
### process object methods (virtual and normal object methods)
###

function produce_function_header(){

    if [ $# -lt 1 ];
    then
       echo "need file include function declaration."    
       exit 1
    fi

    # the orignal form in omfile or vffile is "return_type (*func_name)(para_list);"
    # they are list of function pointers, which are used in ${self_class} struct. 
    # the following steps are taken to generate function header based on function
    # pointers declaration above:
    # 1 remove (* )
    # 2 remove leading whitespace(s)
    # 3 remove ;
    # the result form: return_type func_name(para_list)
    sed -i \
        -e 's/(\*\([a-zA-Z_]\+\))/\1/g'\
        -e 's/^[\t ]\+//g'\
        -e 's/;//g' $1 

}


# for object methods, we don't place their comments into ${self_class} struct
# in .h file, because doing this will make struct unreadable; so we place those
# comments in .c file; these comments with their corresponding method declaration
# are kept in xxdfile, like omdfile or vfdfile. By the way omfile and vffile are
# just keep methods declaration, not with comments.
function process_object_method(){

    if [ -s $1dfile ];
    then
        touch $1list

        # generate function name list from omfile or vffile.
        sed -e 's/.*(\*\([a-zA-Z_]\+\)).*/\1/g' $1file > $1list 

        produce_function_header $1file
    
        while read line;
        do
            func_header=$(sed -n "/$line/p" $1file)

            # 
            sed -i "s/.*$line(.*;/$func_header/g" $1dfile

        done < $1list
    
        append_function_body_to $1list $1dfile
    
        if [[ $1 == "om" ]];
        then
            method_kind="non-virtual"
        else
            method_kind="virtual"
        fi

        echo -e "\n"
        echo "///////////////////////////////////////////////////////////////////////////////"
        echo "//"
        echo "//                    ${method_kind} object methods definition"
        echo "//"
        echo "///////////////////////////////////////////////////////////////////////////////"
        echo ""
        unset kind   

        dos2unix $1dfile>&/dev/null
        cat $1dfile
    fi
}

if [ -e omfile ];
then
    process_object_method "om"
fi

if [ -e vffile ];
then
    process_object_method "vf"
fi





echo -e "\n"
###
###  process constructor and destructor 
###

echo "///////////////////////////////////////////////////////////////////////////////"
echo "//"
echo "//                   object constructor and destructor"
echo "//"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""

# constructor
echo "static void ${lowercase_self}_instance_init(Object *obj)"
extract_function_body "$(construct_pattern ${self} ${self})"
cat fbfile

# destructor, this is optional
extract_function_body "$(construct_pattern ${self} ~${self})"
if [ -s fbfile ];
then
   echo "static void ${lowercase_self}_instance_fininalize(Object *obj)"
   cat fbfile
fi
echo ""





echo -e "\n"
###
###   process binding and type registration 
###

function add_bindings(){
    if [ $# -lt 2 ];
    then
        echo "need a file includes function name list and class name."
        exit 1
    fi

    # add a list of bindings
    while read func_name_line;
    do
       echo "    $2->${func_name_line} = ${func_name_line};"
    done < $1
}


echo "///////////////////////////////////////////////////////////////////////////////"
echo "//"
echo "//                   binding and type registration"
echo "//"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""

self_class_name=$(echo "${self_class}" | tr -d 'a-z' | tr 'A-Z' 'a-z')
parent_class_name=$(echo "${parent_class}" | tr -d 'a-z' | tr 'A-Z' 'a-z')

# class init
echo "static void ${lowercase_self}_class_init(ObjectClass *oc, void *data)"
echo "{"
echo "    ${self_class} *${self_class_name} = ${uppercase_self}_Class(oc);"
echo ""

if [ -e vflist ];
then
echo "    ${parent_class} *${parent_class_name} = ${uppercase_parent}_Class(oc);"
fi

add_bindings omlist ${self_class_name}

echo ""

if [ -e vflist ];
then
    echo "    /*This may not correct, please check yourself.*/"
    add_bindings vflist ${parent_class_name}
fi

echo "}"

# type information
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

#type registration
echo ""
echo "void ${lowercase_self}_register(void)"
echo "{"
echo "    type_register_static(&${lowercase_self}_type_info);"
echo "}"





###
### postprocess for .c file
###
dos2unix ${c_source_file}>&/dev/null

rm -f *file *list 

