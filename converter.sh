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
# to "int **i;"; the second expression is to squash space(s), eg "int   i",
# will be "int i", "int    **i  ;" will be "int **i;"
# Waring: we can't deal with case like "int**i;", which should be write "int** i;"
# or "int **i;" and treated as bad coding style, we just ignore it here.
# we shuold make sure that the substitution not taken place in comments, for 
# previous preprocess, leading whitespace(s) of all lines in .h file are deleted
# so we can use ^[^\/] to guarantee that.
# notice that we don't use [a-zA-Z_]\+ to match variable but use [a-zA-Z_][^ ]
# because chances are the variable is a array, if we use the former one, we can't 
# deal with this case.
sed -i \
    -e 's/\(^[^\/][a-zA-Z_][^()\*]\+\)\(\**\) \+\([a-zA-Z_][^ ]\+\) *;/\1 \2\3;/g'\
    -e 's/\(^[^\/][a-zA-Z_][^()\* ]\+\)\( \+\)\(\**\)\([a-zA-Z_][^ ]\+\) *;/\1 \3\4;/g'\
    formatted_file

# remove whitespace(s) between function name and (
sed -i 's/\([a-zA-Z_]\+\) *(/\1(/g' formatted_file 




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
if [[ ${#self} == 0 ]];
then
     echo "Waring: no class in header file"
     rm -f *file
     exit 1;
fi

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

touch hfile ovfile cvfile cffile pvffile vffile omfile cfile cmfile ccmfile \
    omdfile cfdfile pvfdfile vfdfile fnsfile smfile

awk '

 function clear_comments() {
    system("rm "  comments  " && "  "touch " comments);
 }

 #TODO data mutiline comments should be with indentation
 function write_comments_to(file_to_write, is_multiline_comment, need_indentation){

    if (system("test -s "  comments) == 0){
        
        leading = need_indentation==1 ? "    " : ""

        if (is_multiline_comment) {
            system("echo " "\"" leading "\""  "\/\**"  " >> " file_to_write );

            system("cat "  comments  " >> "  file_to_write);

            # "*/" should has one space indentation
            system("echo " "\"" leading "\""  "\" "  "*/"  "\" " " >> "  file_to_write);
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
 # for previous preprocess on variables, and previous skipping comments in 
 # this awk we can simply use the following regexp to match variables. By the
 # way, we can not use "[a-zA-Z_ ]+" for line contains "func_name()  const;"
 # will matches. for "unsigned int *i;" we just match the "int *i" part, and 
 # that is enough.
 !/static/ && /[a-zA-Z_]+ \**[a-zA-Z_\[\]]+;/{

    #comments for object variable alse need 4 spaces long indentation
    system ("sed -i " "\"" "s/^/    /" "\" " comments);
    write_comments_to(object_variables, is_multiline_comment, 1);

    # with 4 spaces indentation
    system("echo " "\"    "  $0  "\"" " >> " object_variables);
    next
 }

 # extract class variables
 /static/ && /[a-zA-Z_]+ \**[a-zA-Z_]+;/{
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

    ac = get_access_constrol_description(access_control);

    system("echo " "\"" ac  "\" "  "\""  $0  "\""  " >> " class_funcs);
    system("echo " " >> " class_funcs);

    write_comments_to(class_funcs_decl, is_multiline_comment);
    system("echo " "\"" ac  "\" "  "\""  $0  "\""  " >> " class_funcs_decl);
    system("echo "  ">> " class_funcs_decl);


    next
 }
 
 # extract pure virtual functions
 /virtual/ && /=/{
    virtual_func_num++;

    system("echo " "\"    "  $0  "\"" " >> " pure_virtual_funcs);

    write_comments_to(pure_virtual_funcs_decl, is_multiline_comment);
    system("echo " "\"    "  $0  "\"" " >> " pure_virtual_funcs_decl);
    system("echo " " >> " pure_virtual_funcs_decl);

    next
 }

 # extract not pure virtual functions
 /virtual/{
    virtual_func_num++;

    system("echo " "\"    "  $0  "\"" " >> " virtual_funcs);

    write_comments_to(virtual_funcs_decl, is_multiline_comment);
    system("echo " "\"    "  $0  "\"" " >> " virtual_funcs_decl);
    system("echo " " >> " virtual_funcs_decl);

    next
 }

 # extract normal object methods, not include copy, constructor, destructor
 # funcnton
 /[a-zA-Z_] *\(/ && $0 !~ class_pattern{
    object_method_num++;

    system("echo " "\"    "  $0  "\"" " >> " object_methods);

    write_comments_to(object_methods_decl, is_multiline_comment);
    system("echo " "\"    "  $0  "\"" " >> " object_methods_decl);
    system("echo " " >> " object_methods_decl);

    next
  }
 
  # extract method contains class_pattern, maybe constructor, destructor or copy
  # constructor and so on.
  # "^[^a-zA-Z_]*${self}", if self is "TestSuite", then runTestSuite do not match.
  /[a-zA-Z_] *\(/ && $0 ~ class_pattern{
      system("echo " "\""  $0  "\"" " >> " special_methods);
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
  pure_virtual_funcs_decl=pvfdfile pure_virtual_funcs=pvffile\
  special_methods=smfile class_pattern="^[^a-zA-Z_]*${self}"  formatted_file \

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
echo "    $parent parent;"
if [ -s ovfile ];
then
    echo""
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
    -e 's/\([a-zA-Z_]\+\) *\(\**\) *\([a-zA-Z_]\+\)(\(.*\)) *const *= *0 *;/\1\2 (*\3)(const Object *obj, \4);/g' \
    -e 's/\([a-zA-Z_]\+\) *\(\**\) *\([a-zA-Z_]\+\)(\(.*\)) *= *0 *;/\1\2 (*\3)(Object *obj, \4);/g' \
    -e 's/\([a-zA-Z_]\+\) *\(\**\) *\([a-zA-Z_]\+\)(\(.*\)) *const *;/\1\2 (*\3)(const Object *obj, \4);/g' \
    -e 's/\([a-zA-Z_]\+\) *\(\**\) *\([a-zA-Z_]\+\)(/\1\2 (*\3)(Object *obj, /g'  \
    -e 's/, \+void)/)/g' vffile omfile pvffile


sed -i \
    -e 's/\(.*\)) *;/\1);/g'  \
    -e 's/ *, */,/g'  \
    -e 's/,/, /g' vffile omfile pvffile cffile


# tackle non-virtual object method: remove constructor and destructor
# here we just distiguish constructor and destructor between other non-virtual
# object method.
sed -i -e "/${self}(/d" -e '/^$/d' omfile

# tackle virtual object methods: remove virtual keyword.
sed -i 's/virtual \+//g' vffile pvffile

echo "typedef struct $self_class {"
echo "    $parent_class parent_class;"

if [ -s omfile ];
then
    echo " "
    cat omfile
fi

# for non-pure virtual function, we often have no idea about whether it is
# in parent class or in self class; but if we know the parent is class, we 
# can sure that the virtual function should defined in self class.
if [ -s vffile ];
then
    echo " "
    
    if [ ${parent} == "Object" ];
    then
        cat vffile
    else
        echo ">>> // some function may not be in here, please check youself."
        cat vffile
        echo "<<<"
    fi
fi

if [ -s pvffile ];
then
    echo " "
    cat pvffile
    echo " "
fi
echo "} $self_class;"





echo -e "\n"
###
### emit the macros
###
echo "#define ${uppercase_self}_GET_CLASS(obj) \\
        OBJECT_GET_CLASS(${self_class}, obj, TYPE_${uppercase_self})" 
echo ""
echo "#define ${uppercase_self}_CLASS(klass) \\
        OBJECT_CLASS_CHECK(${self_class}, klass, TYPE_${uppercase_self})"

echo ""
echo "#define ${uppercase_self}(obj) \\
        OBJECT_CHECK(${self}, obj, TYPE_${uppercase_self})"



# process constructor with extra parameter(s): define a class-specific
# new function
sed -i -e "/^[a-zA-Z_]\+(.*${self}/d" -e "s/( *void *)/()/" smfile
line_num=`sed -n "/^${self}(.\+)/=" smfile` 

if [[ ${line_num} != '' ]];
then 
    exec 1>&${saved_stdout}

    if [[ ${line_num} == *$'\n'* ]];
    then
      echo "detect multiple constructors"
      exit 1
    fi
    
    echo "detect non-trival constructor"

    dos2unix smfile >&/dev/null
    para_list=$(sed -n "s/^${self}(\(.*\)) *;/\1/p" smfile)

    exec 1>&${c_header_fd}

fi

echo -e "\n"
# add class-specific new function
echo "${self}* ${lowercase_self}_new(${para_list:-void});"



echo -e "\n"
###
###  postprocess for ${self}.h file
###

echo "#endif"
dos2unix  ${c_header} >&/dev/null
exec 1>&${saved_stdout}



dos2unix  *dfile >&/dev/null



###############################################################################
#
#                             generate .c file
#
###############################################################################

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


function generate_source_file(){

    touch ${self}.cpp
    exec {saved_stdout}>&1
    exec {temp_fd}>${self}.cpp 1>&${temp_fd}

    # add copyright information
    echo "//" 
    echo "// Copyright 2004 P&P Software GmbH - All Rights Reserved"
    echo "//"
    echo "// ${self}.c (generated from ${self}.h)"
    echo "//"
    echo "// Version	1.0"
    echo "// Date		12.09.02"
    echo "// Author	A. Pasetti (P&P Software)"
    
    # add include file
    echo ""
    echo -e "#include \"${self}.h\"\n"

    cp vffile tempfile

    produce_function_header tempfile 

    # add blank function body
    sed -i \
        -e 's/)/){\n\n}/g' \
        -e "s/\([a-zA-Z_]\+\)(/${self}::\1(/g" tempfile

    # add constructor
    echo -e "${self}::${self}(void){\n\n}" >> tempfile

    cat tempfile
    rm -f tempfile

}



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
        exec 1>&${saved_stdout}
        echo "Waning: there is no ${self}.cpp and ${self}_inl.h, and we are tring"
        echo "generating a ${self}.cpp for you."
        generate_source_file
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

# add double quotes for included file, for process above the double quotes lost;
# but included file enclosed by <> don't need.
sed -i 's/\(#include\) \+\([^\<]\+\)/\1 \"\2\"/g' shfile

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
# but before remove optional class data initialization, we should backup for latter
# use.
cp shfile _shfile
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
                        }' _shfile)
    
    
    # if there are class variable initialization, then extract them and
    # add corresponding initial value to the cvfile.
    if [[  $has_class_var_init == "yes" ]];
    then
        rm -f cvilist
        touch cvilist
    
        # extract class variable initialization to cvilist, in the form of 
        # "varname=init_valule".
        sed -n 's/.*::\([a-zA-Z_]\+\) *= *\([0-9a-zA-Z_]\+\) *;/\1=\2/gp' _shfile > cvilist
    
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
    
    
    echo -e "\n"
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

   # return constructed pattern
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
   # we tag the start and end line number of the body in the func_body file,
   # after that we can get a range which indicate the location of the function
   # body we want extract.
   range=$(awk '
      BEGIN{
          is_function_body = 0;
          body_start = 0;
          body_end = 0;
      }

      /^\/\//{
           next 
      }

      # find the function 
      $0~pattern{ 
          body_start= NR + 1;
          is_function_body = 1; 
          next
      }

      # assume the end of function "}" is at the begin of line, this can be
      # guaranteed in preprocess phase or we can do ourselves.
      /^\}/{
          if (is_function_body == 0){
              next
          }else{ 
              body_end = NR
              exit 0
          }
       }

      END{
          print body_start, "/", body_end 
      }

     ' pattern="$1" mixed_file)
     
     body_start=${range% /*}
     body_end=${range#*/ }
     
     if [ $body_start != 0 ];
     then
         echo "{" > fbfile
         # using this method, we can preserve special characters in line.
         sed -n "${body_start},${body_end}p" mixed_file >> fbfile
     fi

     rm -f range
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
        # restore stdout for outputing error message
        exec 1>&${saved_stdout}

        echo "sorry, there are more than two functions with the same name"
        echo "dupicate files are the following:"
        echo "$(cat $1 | sort | uniq -c | sed '/1/d')"
        
        exit 1
   fi
}





###
### process class function 
### 

# generate a list of class function name prefixed without ${self}_
sed -n 's/[a-zA-Z_\* ]\+ \([a-zA-Z_]\+\)(.*/\1/gp' cffile > cflist
sed -i "s/${self}_\([a-zA-Z_]\+\)/\1/g" cflist

# check whether cflist has duplicate item
is_duplicate cflist;


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

    while read func_name_line;
    do
        # pattern may contains spaces, so it is necessary to protect it with 
        # double quotes.
        extract_function_body "$(construct_pattern ${self} ${func_name_line})"

        if [ ! -s fbfile ];
        then
            echo -e "{\n    // this is automate genenrated by converter\n}" > fbfile
        fi

        # get the line number where line matchs the function name.
        # until now, xxdfile may contains some function body already appended,
        # so we must make sure that the substitution not taken place in both 
        # the comments and the function body, where a function will be matched. 
        insert_location=$(sed -n "/^[a-zA-Z_][a-zA-Z_\* ]\+$func_name_line(/=" ${func_decl_file})
        
        # if the above regex expression is not comprehensive, the insert_location
        # will contain multiple number separated by newline; we should detect it
        # and come back to revise the regex expression.
        # by the way if a variable contains newline, like var="1\n2\n", we can 
        # use [[ $var == *'\n'* ]] to check.
        if [[ ${insert_location} == *$'\n'* ]];
        then
             exec 1>&${saved_stdout}
             echo "ambiguous insert_location in ${func_decl_file}:"
             echo "${insert_location}"

             cat ${func_decl_file} > debug_info
             rm -f *list *file
             mv debug_info ${func_decl_file}

             exit 1;
        fi 

        # save the upper part of ${func_decl_file}
        sed -n "1,${insert_location}p" ${func_decl_file} > upper_part
        # save the lower part of ${func_decl_file}
        sed -n "$((insert_location+1)),\$p" ${func_decl_file} > lower_part
        # concatenate the content of fbfile and lower_part respectively 
        cat fbfile lower_part >> upper_part
        # let upper_part be new ${func_decl_file}
        mv upper_part ${func_decl_file}
        
    done < ${func_list_file}

    rm -f lower_part
}

append_function_body_to cflist  cffile

if [ -s cffile ];
then
    echo -e "\n"
    echo "///////////////////////////////////////////////////////////////////////////////"
    echo "//"
    echo "//                            class  methods definition"
    echo "//"
    echo "///////////////////////////////////////////////////////////////////////////////"
    echo ""
    cat cffile
fi





###
### process object methods (virtual and normal object methods)
###

# add staic keyword at the begining of the function decalaration for object
# methods.
sed -i\
    -e 's/^[\t ]\+//g'\
    -e 's/^\(.\+\)/static \1/g' omfile vffile pvffile

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
        sed  's/.*(\*\([a-zA-Z_]\+\)).*/\1/g' $1file > $1list 

        produce_function_header $1file
        
        while read func_name;
        do
           # Warning: if the name of two functions are partially same, then 
           # func_header is a mulit-line result, that will cause sed to report
           # "unterminated `s' command error"; so we must make sure that
           # $func_name is a integral function name, but not part of:
           # ahead of function name should have a " " and a "(" should immediately
           # follow the function name.
           func_header=$(sed -n "/ $func_name(/p" $1file)

           if [[ $func_header == *$'\n'* ]];
           then
               exec 1>&${saved_stdout}
               
               echo "sorry, it seem to be at least two function with the same name \"$func_name\""
               echo "please rectify them before continue converting!"

               rm -f *file *list
               exit 1
           fi

           # until now, xxdfile contains comments and function declaration
           # so we must make sure the substitution not taken place in the comments.
           sed -i "s/^[\t ]\+[a-zA-Z_][a-zA-Z_\* ]\+$func_name(.*;/$func_header/g" $1dfile

        done < $1list
    

        # Warning: for some pure virtual functions, there are no function body
        # in sources file, we must produce a default body for them.
        append_function_body_to $1list $1dfile
    
        case "$1" in
            "om")
                 method_kind="non-virtual"
                 ;;
            "vf")
                 method_kind="non-pure virtual"
                 ;;
            "pvf")
                 method_kind="pure virtual"
                 ;;
             *)
                 exec 1>&${saved_stdout}
                 echo "unknown method kind"
                 exit 1
        esac

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

if [ -s omfile ];
then
    process_object_method "om"

    # check whether omlist has duplicate item
    is_duplicate omlist;
fi

if [ -s vffile ];
then
    process_object_method "vf"

    # check whether vflist has duplicate item
    is_duplicate vflist;
fi


if [ -s pvffile ];
then
    process_object_method "pvf"

    # check whether vflist has duplicate item
    is_duplicate pvflist;
fi



###
###  process constructor and destructor 
###

echo -e "\n"
echo "///////////////////////////////////////////////////////////////////////////////"
echo "//"
echo "//                   object constructor and destructor"
echo "//"
echo "///////////////////////////////////////////////////////////////////////////////"
echo ""

echo "// the following may be useful if you don't need it, just delete." 
echo "// ${self} *This = ${uppercase_self}(obj)"

# constructor
if [[ ${para_list} == '' ]];
then
    echo "static void ${lowercase_self}_instance_init(Object *obj)"
else
    # format parameter list in function header.
    sed -i -e "s/ *, */,/" -e "s/,/, /" mixed_file
    para_list=$(sed -n "s/${self}::${self}(\(.*\))\(.*\)/\1/p" mixed_file)

    echo "static void ${lowercase_self}_post_initialization(Object* obj, ${para_list})"
fi
extract_function_body "$(construct_pattern ${self} ${self})"
cat fbfile


# class-specific new function
echo ""
echo "${self}* ${lowercase_self}_new(${para_list:-void})"
echo "{"

if [[ ${para_list} == '' ]];
then
    echo "    return (${self}*)object_new(TYPE_${uppercase_self});"
else
     echo "${para_list}" | tr ',' '\n' > formal_para
     sed -i\
         -e 's/\([a-zA-Z_\*]\+\) \+\([a-zA-Z_]\)/\2/g'\
         -e 's/\([a-zA-Z_]\+\) \+\**\([a-zA-Z_]\+\)/\2/g'\
         -e 's/^[ ]\+//g' formal_para 

     list=''
     while read line;
     do
        if [[ $list == '' ]];
        then 
            list="$line"; 
        else 
            list="$list, $line"; 
        fi;
     done < formal_para

     rm -f formal_para

     echo "   Object *obj = object_new(TYPE_${uppercase_self});"
     echo "   ${lowercase_self}_post_initialization(obj, ${list});"
     echo ""
     echo "   return (${self}*)obj;"
fi

echo "}"


# destructor, this is optional
extract_function_body "$(construct_pattern ${self} ~${self})"
if [ -s fbfile ];
then
   echo ""
   echo "static void ${lowercase_self}_instance_finalize(Object *obj)"

   cat fbfile

   # this will be used in generating TypeInfo struct later
   has_destructor="yes"
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

if [ -e omlist ] || [ -e pvflist ] || [ -e vflist ];
then
    echo "    ${self_class} *${self_class_name} = ${uppercase_self}_CLASS(oc);"
fi

if [ -e omlist ];
then
    echo ""
    add_bindings omlist ${self_class_name}
fi

if [ -e pvflist ];
then
    echo ""
    add_bindings pvflist ${self_class_name}
fi


# for non-pure virtual function, we often have no idea about whether it is
# in parent class or in self class; but if we know the parent is class, we 
# can sure that the virtual function should defined in self class.
if [ -e vflist ];
then
    echo ""

    if [[ ${parent} == "Object" ]];
    then
        add_bindings vflist ${self_class_name}
    else
        echo ">>> // some bindings may not right, please check yourself."
        echo "    ${parent_class} *${parent_class_name} = ${uppercase_parent}_CLASS(oc);"
        add_bindings vflist ${parent_class_name}
        echo "<<<" 
        add_bindings vflist ${self_class_name}
        echo ">>>"
    fi

fi

echo "}"

# type information
echo ""
echo "static const TypeInfo ${lowercase_self}_type_info = {"
echo "    .name = TYPE_${uppercase_self},"
echo "    .parent = TYPE_${uppercase_parent},"
echo "    .instance_size = sizeof(${self}),"

if [ -s pvffile ];
then
    echo "    .abstract = true,"
else
    echo "    .abstract = false,"
fi

echo "    .class_size = sizeof(${self_class}),"

if [[ ${para_list} == '' ]];
then
    echo "    .instance_init = ${lowercase_self}_instance_init," 
fi

echo "    .class_init = ${lowercase_self}_class_init," 

if [[ ${has_destructor} == "yes" ]];
then
    echo "    .instance_finalize = ${lowercase_self}_instance_finalize" 
fi
echo "};"

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

exec 1>&${saved_stdout}
echo "conversion is done."

rm -f *file *list 
