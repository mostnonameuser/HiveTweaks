#initial data
GRAFT_WALLET_CLI_BIN=`which graft-wallet-cli`
readarray -t CONFIG < pay.cfg
readarray -t IP < IP.list
IP_SIZE=${#IP[@]}
CURRENT[$n]=0
#readarray -t H < history.pay
#H_SIZE=${#H[@]}
#------------------------------------------------------------------------------
#Section 1 (checking quality of 'CURRENT_PAYMENT_HISTORY' and 'BACKUP')
JSON_TXT=$(curl --connect-timeout 10 --max-time 20 -k -4 -s http://${IP[0]}/debug/supernode_list/1 | jq -r '.result')
#checking if 'CURRENT_PAYMENT_HISTORY' NOT_exist
if [ ! -f "history.pay"  ]; then
#creating initial 'PAYMENT_HISTORY'
			m=0
			while [ $m -lt $IP_SIZE ]
			do
			H_SUPERNODE_PUBLIC_ID_KEY[$m]=`curl --connect-timeout 2 --max-time 2  -k -4 -s http://${IP[m]}/dapi/v2.0/cryptonode/getwalletaddress | jq -r '.id_key'`
			num=`echo "$JSON_TXT" | grep -n "${H_SUPERNODE_PUBLIC_ID_KEY[m]}" | cut -d : -f 1`
			num=$(( $num + 2 ))
			P=`echo "$JSON_TXT" | head -n"$num" | tail -1 | cut -d ':' -f 2 | tail -c +2 | rev | cut -c 2- | rev`
				if [[ ${P} != 0 ]]; then
					echo "${P}" >> history.pay
				else
					echo "$m" >> history.pay
				fi
			m=$(( $m + 1 ))
			done
		        echo "Initial history.pay created. $(date)" >> errors.log
		        echo "Initial history.pay created. $(date)"
fi
readarray -t H < history.pay
H_SIZE=${#H[@]}
			if [[ $H_SIZE != $IP_SIZE ]]; then
#if 'BACKUP' is broken - creating initial 'PAYMENT_HISTORY'
				echo "Payment_History_Backup broken! $(date)"
				echo "Payment_History_Backup broken! $(date)" >> errors.log
				rm history.pay
			        m=0
			        while [ $m -lt $IP_SIZE ]
			        do
		                        H_SUPERNODE_PUBLIC_ID_KEY[$m]=`curl --connect-timeout 2 --max-time 2  -k -4 -s http://${IP[m]}/dapi/v2.0/cryptonode/getwalletaddress | jq -r '.id_key'`
		                        num=`echo "$JSON_TXT" | grep -n "${H_SUPERNODE_PUBLIC_ID_KEY[m]}" | cut -d : -f 1`
		                        num=$(( $num + 2 ))
		                        P=`echo "$JSON_TXT" | head -n"$num" | tail -1 | cut -d ':' -f 2 | tail -c +2 | rev | cut -c 2- | rev`
		                                if [[ ${P} != 0 ]]; then
	       	                                echo "${P}" >> history.pay
		                                else
	                                        echo "$m" >> history.pay
	                                fi
#			        echo "$m" >> history.pay
			        m=$(( $m + 1 ))
			        done
			fi
#fi

#reading 'CURRENT_PAYMENT_HISTORY' to array
readarray -t PREV < history.pay
#reading CURRENT NODES list
#JSON_TXT=$(curl --connect-timeout 10 --max-time 20 -k -4 -s http://${IP[n]}/debug/supernode_list/1 | jq -r '.result')
if [[ ${#JSON_TXT} == 0 ]];then
	echo "Response error!!!"
	echo "Response error!!! $(date)" >> errors.log
fi
#END of 'checking history and backup section'
#-----------------------------------------------------------------------------
#Section 2 (Reading 'DATA' for all nodes in 'IP.list' and 'pay.cfg')
echo "Checking supernodes in IP.list $(date)"
n=0
while [ $n -lt $IP_SIZE ]
	do
#checking disabled nodes in 'pay.cfg'
	SKIP[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 1`
	SUPERNODE_PUBLIC_ID_KEY[$n]=`curl --connect-timeout 2 --max-time 2  -k -4 -s http://${IP[n]}/dapi/v2.0/cryptonode/getwalletaddress | jq -r '.id_key'`
#echo "${SUPERNODE_PUBLIC_ID_KEY[n]} node pubID"
	if [[ ${SKIP[n]} == "#" ]]; then
		SN_OWNER[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 2` 
		echo "${SN_OWNER[n]} SN with ID_KEY ${SUPERNODE_PUBLIC_ID_KEY[n]} disabled"
                CURRENT[$n]=${PREV[n]}
		n=$(( $n + 1 ))
#if node 'n' active, then reading it 'DATA'
	else
		JSON_SIZE=${#JSON_TXT}
		string=`echo "$JSON_TXT" | grep -n "${SUPERNODE_PUBLIC_ID_KEY[n]}" | cut -d : -f 1`
		string=$(( $string + 1 ))
		test=`echo "$JSON_TXT" | head -n"$string" | tail -1 | cut -d ':' -f 2`
		STAKE_R=${test// /}
#reading 'STAKE_AMOUNT' of 'n'-node in 'pay.cfg'
		STAKE_AMOUNT[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 6`
		ST=`echo "$STAKE_R" | rev |cut -c 12- | rev`
#checking if 'DOUBLE_STAKING' applied
		DB=$(( ${STAKE_AMOUNT[n]} * 2 )) 
		if [[ $DB -lt $ST ]]; then 
                        SN_OWNER[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 2`
			echo "${SN_OWNER[n]} SN DOUBLE STAKING DETECTED!!! Currently paid $ST GRFT instead of ~${STAKE_AMOUNT[n]} GRFT." 
			echo "${SN_OWNER[n]} DOUBLE PAY DETECTED $(date)" >> double_pay.log 
                        CURRENT[$n]=${PREV[n]}
		else
#if there is no 'DOUBLE_STAKING' - continue reading 'n'-node 'DATA'
			SUPERNODE_SIGNATURE[$n]=`curl --connect-timeout 10 --max-time 20 -k -4 -s http://${IP[n]}/dapi/v2.0/cryptonode/getwalletaddress | jq -r '.signature'`
			HEIGHT=`echo "$JSON_TXT" | grep "height" | cut -d ':' -f 2`
#checking availability of current blockchain HEIGHT data
			if [[ ${#HEIGHT} == 0 ]];then
			SN_OWNER[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 2`
	                echo "${SN_OWNER[n]} HEIGHT error!!!"
	                echo "${SN_OWNER[n]} HEIGHT error!!! $(date)" >> errors.log
			CURRENT[$n]=${PREV[n]}
	                n=$(( $n + 1 ))
			exit 1
			fi
			SN_OWNER[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 2`
			WALLET_FILE[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 3`
			WALLET_PASSWORD[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 4`
			SUPERNODE_WALLET_PULIC_ADDRESS[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 5`
			STAKE_AMOUNT[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 6`
			LOCK_BLOCKS_COUNT[$n]=`echo ${CONFIG[n]} | cut -d ';' -f 7`
			MYNODE[$n]=`echo ${JSON_TXT}| jq '.items[] | select(.PublicId == "'${SUPERNODE_PUBLIC_ID_KEY[n]}'") | .'`
#echo "${MYNODE[n]} - MY_NODE"
			STAKEAMOUNTLIVE[$n]=`echo ${MYNODE[n]} | jq -r '.StakeExpiringBlock'`
#checkingg availability of SN[n] TTL Data 
                        if [[ ${#STAKEAMOUNTLIVE[n]} == 0 ]];then
                        echo "${SN_OWNER[n]} TTL error!!!"
                        echo "${SN_OWNER[n]} TTL error!!! $(date)" >> errors.log
			CURRENT[$n]=${PREV[n]}
			n=$(( $n + 1 ))
			exit 2
                        fi
#getting 'TTL' - TimeToLive for 'n'-node and 'LAST_PAYMENT' info
			TTL[$n]=$(( ${STAKEAMOUNTLIVE[n]} - $HEIGHT ))
			PAY_DELAY[$n]=$(( $HEIGHT - ${PREV[n]} ))
#if 'TTL'< 7 blocks and 'LAST_PAYMENT' was more than 15 blocks ago, launching payment for 'n'-node
			if [[ ${TTL[n]} -lt 8 && ${PAY_DELAY[n]} -gt 15 ]]; then
#checking 'UNLOCKED_BALANCE' at wallet fofr 'n'-node in 'pay.cfg'
				./graft-wallet-cli --wallet-file ${WALLET_FILE[n]} --password ${WALLET_PASSWORD[n]} --command refresh > balance.info
				BAL[$n]=`grep "unlocked balance" balance.info | cut -d ':' -f 3 | cut -d '.' -f 1`
#echo "${BAL[n]} - balance"
				BALANCE[$n]=`echo ${BAL[n]} | cut -c 1-`
#echo "REAL BALANCE - ${BALANCE[n]}"
					if [[ ${BALANCE[n]} -lt ${STAKE_AMOUNT[n]} ]]; then
#if not enough
						echo "${SN_OWNER[n]} SN payment cancelled. Your balance is ${BALANCE[n]} GRFT. You need at least ${STAKE_AMOUNT[n]} GRFT"
						CURRENT[$n]=${PREV[n]}
					else
#else continue payment
					walletCMD="./graft-wallet-cli --wallet-file ${WALLET_FILE[n]}"
						echo "${SN_OWNER[n]} SN is almost empty. Sending payment."
expect - <<EOD
	set timeout 3
	spawn $walletCMD
		expect	{*?assword:*} {send "${WALLET_PASSWORD[n]}\n"}
	sleep 2
		expect	{*?wallet*} {send "save\n"}
	sleep 3
		expect	{*?wallet*} {send "stake_transfer ${SUPERNODE_WALLET_PULIC_ADDRESS[n]} ${STAKE_AMOUNT[n]} ${LOCK_BLOCKS_COUNT[n]} ${SUPERNODE_PUBLIC_ID_KEY[n]} ${SUPERNODE_SIGNATURE[n]}\n"}
		expect	{*?assword:*} {send "${WALLET_PASSWORD[n]}\n"}
	sleep 6
		expect "*?Stake amount will be locked*"
	sleep 4
		send "Y\n"
		expect	{
			"?No payment id*" { send "Y\n" }
			}
		expect	{
			"*?backlog at that*" { send "Y\n" }
			"*?noug*" { sleep 5; send "exit\n" }
			}
	sleep 5
		expect	{
			"*?The transaction fee*" { send "Y\n" }
			"*?double*" { sleep 5; send "exit\n" }
			}
		expect "*?comman*"
			send "exit\n"
	sleep 5
EOD
#putting current block № in 'history.pay'
						CURRENT[$n]=$HEIGHT
						echo "${SN_OWNER[n]} SN paid $(date)"
					fi
				else
#if there was no payment - putting previous payment block № to 'history.pay'
	                                if [[ ${TTL[n]} -le 0 ]]; then
	                                TTL[$n]=0
	                                fi
					echo "${SN_OWNER[n]} SN has ${TTL[n]} blocks more. Last payment ${PAY_DELAY[n]} blocks ago" 
					CURRENT[$n]=${PREV[n]}
				fi
		fi
		n=$(( $n + 1 ))
#going to next 'n+1'-node
	fi
done
#after scrypt checked all nodes and there were no errors - saving 'history.pay' and 'history.back'
if [[ ${#CURRENT[@]} != $IP_SIZE ]]; then
        echo "Script failed!"
	echo "Script failed!" >> errors.log
else
#saving new history.pay
	if [[ ${CURRENT[@]} != ${H[@]} && ${#CURRENT[@]} == $IP_SIZE ]]; then
	echo "updating history.pay"
	rm history.pay
	for i in "${CURRENT[@]}"; do echo $i >> history.pay; done
	echo "Payment.History saved in history.pay"
	fi
fi
#exit 0
