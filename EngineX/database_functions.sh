#!/usr/bin/env bash

dbName=""; #this holds the name of the current database
dbs=($(ls ../database)); #initializing #this holds all the names of the existing databases


function create_table {
    fields=($@);
    number_fields=${#fields[@]};
    if [ -f ../database/$dbName/database/${fields[2]} ];
    then
        echo "${fields[2]} table already exist";
        return 1;
    fi
    colName="";
    colType="";
    for (( i = 4; i < ${number_fields}-1; ++i )); do
        IFS=',' read -r -a array <<< "${fields[${i}]}";
        colName=$colName":";
        colName=$colName${array[0]};
        colType=$colType":";
        colType=$colType${array[1]};
    done
    IFS=':' read -r -a colNames <<< ${colName};
    for (( i = 1; i < ${#colNames[@]}; ++i )); do
        for (( j = i+1; j < ${#colNames[@]}; ++j )); do
            if [ ${colNames[i]} == ${colNames[j]} ]
            then
                echo "more than one column with same name";
                return 1;
            fi
        done
    done

    echo '**********************************'
    echo '  Table is Created Successfully!  '
    echo '**********************************'
    touch ../database/$dbName/database/${fields[2]};
    touch ../database/$dbName/metadata/${fields[2]};
    echo $colName >> ../database/$dbName/metadata/${fields[2]}
    echo $colType >> ../database/$dbName/metadata/${fields[2]}
    return 0;
}

function insert_into {

    fields=($@);
    number_fields=${#fields[@]};
    if [ ! -f ../database/$dbName/database/${fields[2]} ];
    then
        echo "${fields[2]} table not exist";
        return 1;
    fi
    row="";
    stringFlag=0;
    colVal=""
    IFS=':' read -r -a colNames <<< `sed -n '1p' ../database/$dbName/metadata/${fields[2]}`;
    IFS=':' read -r -a colTypes <<< `sed -n '2p' ../database/$dbName/metadata/${fields[2]}`;
    typeset -i colNumber=0
    for (( i = 4; i < ${number_fields}-1; ++i )); do
        if [ $stringFlag -eq 0 ]
        then

            colVal=""
            colNumber=$colNumber+1;
            IFS='=' read -r -a array <<< "${fields[${i}]}";
            if [ ${colNumber} -ge ${#colNames[@]} ]
            then
                echo "many columns exist";
                return 1;
            fi
            if [ ${array[0]} != ${colNames[${colNumber}]} ]
            then
                echo "${colNames[${colNumber}]} column not exist";
                return 1;
            fi

        fi
        if [[ ${array[1]} =~ ^\" && $stringFlag -eq 0 ]]
        then
            if [ ${colTypes[${colNumber}]} != "text" ]
            then
                echo "wrong datatype of ${colNames[${colNumber}]}";
                return 1;
            fi
            colVal=$colVal${array[1]}
            if  [[ ${array[1]} =~ \"$ ]]
            then
                row=$row":"$colVal
                continue;
            fi
            stringFlag=1;
            continue;
        fi

        if [ $stringFlag -eq 1 ]
        then
            colVal=$colVal" "${fields[${i}]}
            if [[ ${fields[${i}]} =~ \"$ ]]
            then
                row=$row":"$colVal
                stringFlag=0;
            fi
            continue;
        fi

        if [ ${colTypes[${colNumber}]} != "int" ]
        then
            echo "wrong datatype ${colNames[${colNumber}]}";
            return 1;
        fi
        colVal=${array[1]}
        row=$row":"$colVal
    done
    if [[ ${colNumber}+1 -ne ${#colNames[@]} ]]
    then
        echo "few columns"
        return 1;
    fi
    echo $row | sed -r 's/\"//g' >> ../database/$dbName/database/${fields[2]}
    return 0
}

function delete_from_table {
    fields=($@);
    number_fields=${#fields[@]};
    if [ ! -f ../database/${dbName}/database/${fields[2]} ];
    then
        echo "${fields[2]} table not exist";
        return 1;
    fi
    IFS=':' read -r -a colNames <<< `sed -n '1p' ../database/${dbName}/metadata/${fields[2]}`;
    IFS=':' read -r -a colTypes <<< `sed -n '2p' ../database/${dbName}/metadata/${fields[2]}`;

    IFS='=' read -r -a arr <<< "${fields[4]}";
    colName=${arr[0]};
    colVal=${arr[1]};
    colType=int;
    lineNum=0;
    for (( i = 5; i < ${number_fields}-1; ++i )); do
        colVal=$colVal" "${fields[${i}]}
        colType=text;
    done
    if [[ $colVal =~ \"$ ]]
    then
        colType=text;
    fi
    for (( i = 1; i < ${#colNames[@]}; ++i )); do
        if [[ ${colNames[${i}]} = $colName && ${colTypes[${i}]} = $colType ]]
        then
            typeset -i linesUpdated=0
            typeset -i index=i;
            index=$index+1
            for lineNum in `awk -F: -v colNum="${index}"  -v colVal="$colVal"  'BEGIN{lineNum=-1}{
                gsub("\"","",colVal);
                for(j=2;j<=NF;++j)
                {

                    if(colVal == $j && colNum == j) {
                        lineNum=NR;
                        print lineNum
                    }
                }

            }' ../database/${dbName}/database/${fields[2]}`; do
               sed -i "$lineNum s/.*//" ../database/${dbName}/database/${fields[2]};
               linesUpdated=$linesUpdated+1;
            done
            echo "${linesUpdated} Rows Deleted";
            break;
        fi
    done
    sed -i '/^[[:space:]]*$/d' ../database/${dbName}/database/${fields[2]};
    return 0;
}

function listDatabases {
   dbs=($(ls ../database/)); #for updating
   for(( i=0; i<${#dbs[@]}; i++ ))
   do
   echo "  -- ${dbs[$i]}"
   done
}

function createDatabase {
    read -p "Enter DB Name: " dbName;
    isFound=false;
    for(( i=0; i<${#dbs[@]}; i++ ))
    do
    if [ "${dbs[$i]}" == "$dbName" ] ; then
     isFound=true;
     break;
   fi
   done
   if [ "$isFound" = true ] ; then
     echo '*************************************************************************'
     echo "There's already a database named: $dbName. Please choose another name."
     echo '*************************************************************************'
   else
    mkdir -p ../database/$dbName/database #for data itself
    mkdir ../database/$dbName/metadata    #for metadata
    dbs=($(ls ../database/)); #for updating
    echo '********************************'
    echo '   DB is Created Successfully!  '
    echo '********************************'
   fi
   mainMenu
}

function connectToDatabase {
   read -p "Enter DB Name: " dbName;
   isFound=false;
   for(( i=0; i<${#dbs[@]}; i++ ))
   do
   if [ "${dbs[$i]}" == "$dbName" ] ; then
     #cd database/$dbName
     isFound=true;
     break;
   fi
   done
   if [ "$isFound" = true ] ; then
     echo '********************************'
     echo "       $dbName is Selected      "
     echo '********************************'
     redirectToDBSystem
   else
     echo '**********************************************'
     echo "$dbName is not Found, Please Select a Valid DB"
     echo '**********************************************'
     mainMenu
   fi
}

function redirectToDBSystem {
  echo '*****************************************************'
  echo "  You can now:     "
  echo "           1) List Tables in DB"
  echo "           2) Create Tables in DB"
  echo "           3) Insert Rows into a Table in DB"
  echo "           4) Delete Rows from a Table"
  echo "           5) Select All Rows form a Table in DB"
  echo "           6) Go Back to Main Menu          "
  echo "           7) For help, type HELP ;          "
  echo '*****************************************************'
  read_query
}

function listTables {
 database=$2
 if test ! -d "../database/$database" ; then
  echo '**********************************************'
  echo 'Misspelled Database Name. Please Check it!'
  echo '**********************************************'  
 elif [ "$(ls -A ../database/$database/database)" ] ; then
  tables=($(ls ../database/$database/database))
  for(( i=0; i<${#tables[@]}; i++ ))
   do
    echo "  -- ${tables[$i]}"
   done
 else
  echo '**************************************************'
  echo 'Database is Empty. Create New Tables to Save :)'
  echo '**************************************************'
 fi
}

function selectAll {
  tableName=$4;
  tables=($(ls ../database/$dbName/database))
  isFound=false;
  for(( i=0; i<${#tables[@]}; i++ ))
   do
    if [ "${tables[$i]}" == "$tableName" ] ; then
     isFound=true;
     break;
   fi
   done
  if [ "$isFound" = true ] ; then
    sed -n '1p' ../database/$dbName/metadata/$tableName | tr ":" "\t"; #header
    cat ../database/$dbName/database/$tableName | tr ":" "\t";         #data
  else
    echo '*********************************'
    echo '       Table is not Found        '
    echo '*********************************'
  fi
}

function showHelpInstructions {
  echo '*****************************************************'
  echo "  Welcome to Help :)     "
  echo "     1) For Listing Tables in a DB, type LIST database_name ;"
  echo "     2) For Creating Tables in a DB, type CREATE TABLE table_name CLOUMNS col_name,col_datatype .. ;"
  echo "     3) For Inserting Rows into a Table, type INSERT INTO table_name ROW col1_name=value1 ... ;"
  echo "     4) For Deleting Rows from a Table, type DELETE FROM table_name WHERE condition ;"
  echo "     5) For Selecting All Rows form a Table, type SELECT ALL FROM table_name ;"
  echo "     6) For Going Back to Main Menu, type BACK ;          "
  echo '*****************************************************'
}

echo '***********************'
echo '  Welcome to EngineX   '
echo '***********************'

PS3="Enter Your Choice> "

function mainMenu {
 while true
 do
  select choice in 'List DBs' 'Create DB' 'Connect to DB' 'Exit'
  do
   case $choice in
    'List DBs')
    listDatabases
    break;
    ;;
    'Create DB')
    createDatabase
    break;
    ;;
    'Connect to DB')
    connectToDatabase
    break 2;
    ;;
    Exit)
    echo '************'
    echo '    bye!    '
    echo '************'
    exit
    break 2;
    ;;
   esac
  done
 done
}