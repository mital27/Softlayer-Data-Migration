source app.cfg

arr=$(echo $source_containers | tr "," "\n")
echo "Source container : $arr"

#Create logs file

current_time=$(date '+%Y.%m.%d-%H.%M.%S')

log_directory=$(pwd)
log_file="logs.txt".$current_time
report_file="Migration_report.txt"
echo "Starting migration of data....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file

destination_account=$dest_account
destination_account+="_$dest_location"

if [ -f $working_directory/$destination_account.sh ]
then
        echo "Destination account: $destination_account.sh exists....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
else
        echo "Destination account: $destination_account.sh doesnot exists.So exiting....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
        echo "Check log file $log_directory/$log_file for errors."
        exit 1
fi


source_acc=$source_account
source_acc+="_$source_location"

if [ -f $working_directory/$source_acc.sh ]
then
        echo "Source account: $source_acc.sh exists....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
else
        echo "Source account: $source_acc.sh doesnot exists.So exiting....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
        echo "Check log file $log_directory/$log_file for errors."
        exit 1
fi

#Check for existence of report file in present working directory

if [ -f $log_directory/$report_file ]
then
        echo "Report file already exixts....."
else
        echo "Creating a report file for logging data migration details ....... ">$log_directory/$report_file
fi

echo -e "\n\nPlease find below the data migration report from source account :$source_acc to destination account :$destination_account $(date "+%Y.%m.%d-%H.%M.%S")">>$log_directory/$report_file

source "$working_directory/$source_acc.sh"


#Check whether the source container is available in the object storage.

container_flag=0
object_flag=0
container_list=`swift list`
container_size_check=5242880

for source_container in $arr
do
	for container in $container_list
	do
		if [ "$source_container" = "$container" ]
		then
			container_size=$(swift list -l | grep -w ${container} | awk '{print $2}')
			divisor=1024
			container_size_kb=$((container_size / divisor))
                        device_size=$(df -k /tmp | awk '{print $4}' | tail -1)
                        if [ $container_size_kb -ge $device_size ]
                        then
                                echo "Container could not be downaload as the available space on the device is low"
                                echo "Container size : $container_size"
                                echo "Device Size : $device_size"
                        else
			echo "Source container : $source_container is present on in the object store of source account"
			container_flag=1
			if [ $source_objects == all ]
			then 			
				echo "Downloading source container : $source_container"
				rm -rf $mount_point/$source_container
				mkdir $mount_point/$source_container
			        cd $mount_point/$source_container		

				download_flag=0
				
				#Download the container locally
				 retry_count=0
                                 while [ $retry_count -le 3 ]; do
					download_start=$(date +"%s")
	                                echo "Starting dowmload of source container:$source_container...$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
                                        echo "Attempt:$((retry_count+1))">>$log_directory/$log_file

					swift download $source_container --object-threads $download_thread_count --skip-identical
					
                                        if [ $? -ne 0 ]
                                        then
        	                                echo "Download was failed.. Retrying"
                                                retry_count=$((retry_count+1))
					else
						download_stop=$(date +"%s")
						download_flag=1
						break
                                        fi
                                 done
				
				#Upload the downloaded container 
				if [ "$download_flag" -eq 1 ]
				then
					diff=0
                                        diff=$(($download_stop-$download_start))
                                        download_difference="$(($diff / 3600 )) hours $((($diff % 3600) / 60)) minutes and $(($diff % 60)) seconds"
					echo "Download of source container is successful...."
					echo "Download of source container is successful....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
					
					source_container_size="`du -sk $mount_point/$source_container | cut -f1`"
					echo -e "\nDownload of source container:$source_container of size:$source_container_size required $download_difference to download.">>$log_directory/$report_file
                                        if [ $source_container_size -ge $container_size_check ]
                                        then
						retry_count=0
						upload_flag=0
						echo "Greater than 5GB">>$log_directory/$log_file
                                        	#while [ $retry_count -le 3 -a $upload_flag -ne 1]; do
						while [[ $retry_count -le 3 && $upload_flag != 1 ]]; do
							source "$working_directory/$destination_account.sh"
							dest_list=`swift list`
							echo "Starting upload of source container....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
							upload_start=$(date +"%s")
							swift -v upload $source_container $mount_point/$source_container -c -S $upload_chunk_size
							if [ $? -ne 0 ]
	                        	                then
        	                        	                echo "Upload was failed.. Retrying"							
	                	                                retry_count=$((retry_count+1))
								echo "Attempt:$retry_count..$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
        	                	                else
								upload_stop=$(date +"%s")
								echo "Upload of source container is successful....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
								diff1=0
                                        			diff1=$(($upload_stop-$upload_start))
                                        			upload_difference="$(($diff1 / 3600 )) hours $((($diff1 % 3600) / 60)) minutes and $(($diff1 % 60)) seconds"
		                                                echo -e "\nUpload of source container:$source_container of size:$source_container_size required $upload_difference to upload.">>$log_directory/$report_file
								source "$working_directory/$source_acc.sh"                	                	                                                   	       upload_flag=1
								break
	                                        	fi
						done
					else
                                                echo "Less than 5GB">>$log_directory/$log_file
						retry_count=0
						upload_flag=0
#                                                while [ $retry_count -le 3 -a $upload_flag -ne 1 ]; do
						while [[ $retry_count -le 3 && $upload_flag != 1 ]]; do
							source "$working_directory/$destination_account.sh"
        	                                        dest_list=`swift list`
							echo "Starting upload of source container....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
							upload_start=$(date +"%s")
                        	                        swift -v upload $source_container $mount_point/$source_container -c
							if [ $? -ne 0 ]
	                                                then
                        		        	        echo "Upload was failed.. Retrying"
								retry_count=$((retry_count+1))
	                                 	                echo "Attempt:$retry_count..$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
							else
								upload_stop=$(date +"%s")
								echo "Upload of source container is successful....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
								diff1=0
                                                                diff1=$(($upload_stop-$upload_start))
                                                                upload_difference="$(($diff1 / 3600 )) hours $((($diff1 % 3600) / 60)) minutes and $(($diff1 % 60)) seconds"
                                                                echo -e "\nUpload of source container:$source_container of size:$source_container_size required $upload_difference to upload.">>$log_directory/$report_file
								source "$working_directory/$source_acc.sh"
								upload_flag=1
								break
						        fi
						done
					fi
					#Delete the downloaded local copy of the container

                                        if [ -d $mount_point/$source_container ]
                                        then
                                                rm -rf $mount_point/$source_container
                                        fi

                                        #Verify for successful deletion of the Container.

                                        if [ ! -d $mount_point/$source_container ]
                                        then
                                                echo "Successfully deleted the downloaded container....."
						echo "Successfully deleted the downloaded container.....$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
                                        fi
				fi
			else
				object_list=`swift list $source_container`
				echo $object_list
				for object in $object_list
				do
					if [ "$source_objects" = "$object" ]
					then 
						echo "Source object also present in the source container.So downloading object : $source_objects from source container : $source_container "
						rm -rf $mount_point/$source_container
						mkdir $mount_point/$source_container
		                                cd $mount_point/$source_container

 		                                #Download the container locally
						retry_count=0
						while [ $retry_count -le 3 ]; do
						        swift download $source_container $source_objects

							if [ $? -ne 0 ]
	        	                                then
        	        	                                echo "Download was failed.. Retrying"
								retry_count=$((retry_count+1))
							else
								break
	                        	                fi	
						done
					else
						echo "Source object was not found in the source container."
					fi
					
				done	
			fi
		fi
	fi
	done

	if [ "$container_flag" -eq "0" ]
        then
                echo "Source container : $source_container was not found on in the object store of source account.So exiting ..."
		echo "Source container : $source_container was not found on in the object store of source account.So exiting ...$(date '+%Y.%m.%d-%H.%M.%S')">>$log_directory/$log_file
        fi

	container_flag=0
	echo "Check log file $log_directory/$log_file for all migration related details."
done
