package WebGUI::Operation::User;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2004 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict qw(vars subs);
use Tie::CPHash;
use Tie::IxHash;
use WebGUI::AdminConsole;
use WebGUI::DateTime;
use WebGUI::FormProcessor;
use WebGUI::Group;
use WebGUI::Grouping;
use WebGUI::HTMLForm;
use WebGUI::Icon;
use WebGUI::International;
use WebGUI::Operation::Auth;
use WebGUI::Paginator;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::Style;
use WebGUI::URL;
use WebGUI::User;
use WebGUI::Utility;


#-------------------------------------------------------------------
sub _submenu {
        my $workarea = shift;
        my $title = shift;
        $title = WebGUI::International::get($title) if ($title);
        my $help = shift;
        my $ac = WebGUI::AdminConsole->new("users");
        if ($help) {
                $ac->setHelp($help);
        }
	if (WebGUI::Grouping::isInGroup(3)) {
		$ac->addSubmenuItem(WebGUI::URL::page("op=addUser"), WebGUI::International::get(169));
		unless ($session{form}{op} eq "listUsers" 
			|| $session{form}{op} eq "addUser" 
			|| $session{form}{op} eq "deleteUserConfirm") {
			$ac->addSubmenuItem(WebGUI::URL::page("op=editUser&uid=".$session{form}{uid}), WebGUI::International::get(457));
			$ac->addSubmenuItem(WebGUI::URL::page("op=editUserGroup&uid=".$session{form}{uid}), WebGUI::International::get(458));
			$ac->addSubmenuItem(WebGUI::URL::page("op=editUserProfile&uid=".$session{form}{uid}), WebGUI::International::get(459));
			$ac->addSubmenuItem(WebGUI::URL::page('op=viewProfile&uid='.$session{form}{uid}), WebGUI::International::get(752));
			$ac->addSubmenuItem(WebGUI::URL::page('op=becomeUser&uid='.$session{form}{uid}), WebGUI::International::get(751));
			$ac->addSubmenuItem(WebGUI::URL::page('op=deleteUser&uid='.$session{form}{uid}), WebGUI::International::get(750));
			if ($session{setting}{useKarma}) {
				$ac->addSubmenuItem(WebGUI::URL::page("op=editUserKarma&uid=".$session{form}{uid}), WebGUI::International::get(555));
			}
		}
		$ac->addSubmenuItem(WebGUI::URL::page("op=listUsers"), WebGUI::International::get(456));
	} else {
		$ac->addSubmenuItem(WebGUI::URL::page("op=addUser"), WebGUI::International::get(169));
	}
        return $ac->render($workarea, $title);
}
                                                                                                                                                       

#-------------------------------------------------------------------
sub doUserSearch {
	my $op = shift;
	my $returnPaginator = shift;
	my $userFilter = shift;
	push(@{$userFilter},0);
	my $selectedStatus;
	if ($session{scratch}{userSearchStatus}) {
		$selectedStatus = "status='".$session{scratch}{userSearchStatus}."'";
	} else {
		$selectedStatus = "status like '%'";
	}
	my $keyword = $session{scratch}{userSearchKeyword};
	if ($session{scratch}{userSearchModifier} eq "startsWith") {
		$keyword .= "%";
	} elsif ($session{scratch}{userSearchModifier} eq "contains") {
		$keyword = "%".$keyword."%";
	} else {
		$keyword = "%".$keyword;
	}
	$keyword = quote($keyword);
	my $sql = "select users.userId, users.username, users.status, users.dateCreated, users.lastUpdated,
		email.fieldData as email from users left join userProfileData email on users.userId=email.userId and email.fieldName='email'
		where $selectedStatus  and (users.username like ".$keyword." or email.fieldData like ".$keyword.") 
		and users.userId not in (".quoteAndJoin($userFilter).")  order by users.username";
	if ($returnPaginator) {
        	my $p = WebGUI::Paginator->new(WebGUI::URL::page("op=".$op));
		$p->setDataByQuery($sql);
		return $p;
	} else {
		my $sth = WebGUI::SQL->read($sql);
		return $sth;
	}
}


#-------------------------------------------------------------------
sub getUserSearchForm {
	my $op = shift;
	my $params = shift;
	WebGUI::Session::setScratch("userSearchKeyword",$session{form}{keyword});
	WebGUI::Session::setScratch("userSearchStatus",$session{form}{status});
	WebGUI::Session::setScratch("userSearchModifier",$session{form}{modifier});
	my $output = '<div align="center">';
	my $f = WebGUI::HTMLForm->new(1);
	$f->hidden("op",$op);
	foreach my $key (keys %{$params}) {
		$f->hidden(
			-name=>$key,
			-value=>$params->{$key}
			);
	}
	$f->hidden(
		-name=>"doit",
		-value=>1
		);
	$f->selectList(
		-name=>"modifier",
		-value=>([$session{scratch}{userSearchModifier}] || ["contains"]),
		-options=>{
			startsWith=>WebGUI::International::get("starts with"),
			contains=>WebGUI::International::get("contains"),
			endsWith=>WebGUI::International::get("ends with")
			}
		);
	$f->text(
		-name=>"keyword",
		-value=>$session{scratch}{userSearchKeyword},
		-size=>15
		);
	$f->selectList(
		-name	=> "status",
		-value	=> [$session{scratch}{userSearchStatus} || "users.status like '%'"],
		-options=> { 
			""		=> WebGUI::International::get(821),
			Active		=> WebGUI::International::get(817),
			Deactivated	=> WebGUI::International::get(818),
			Selfdestructed	=> WebGUI::International::get(819)
			}
	);
	$f->submit(WebGUI::International::get(170));
	$output .= $f->print;
	$output .= '</div>';
	return $output;
}


#-------------------------------------------------------------------
sub www_addUser {
    my ($output, $f, $cmd, $html, %status);
    return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3) || WebGUI::Grouping::isInGroup(11));
	WebGUI::Style::setScript($session{config}{extrasURL}."/swapLayers.js", {language=>"JavaScript"});
	$output .= '<script language="JavaScript" > var active="'.$session{setting}{authMethod}.'"; </script>';
			
	if ($session{form}{op} eq "addUserSave") {
		$output .= '<ul><li>'.WebGUI::International::get(77).' '.$session{form}{username}.'Too or '.$session{form}{username}.'02</ul>';
	}
	
	$f = WebGUI::HTMLForm->new(-tableOptions=>"border=0 cellspacing=0 cellpadding=0");
	$f->hidden("op","addUserSave");
	$f->raw('<tr><td width="170">&nbsp;</td><td>&nbsp;</td></tr>');
    $f->text("username",WebGUI::International::get(50),$session{form}{username});
    $f->email("email",WebGUI::International::get(56));
    
	if(WebGUI::Grouping::isInGroup(3)){    
	   tie %status, 'Tie::IxHash';
	   %status = (
		   Active		=>WebGUI::International::get(817),
		   Deactivated	=>WebGUI::International::get(818)
		   );
	   $f->select("status",\%status,WebGUI::International::get(816), ['Active']);
       $f->group(
		     -name=>"groups",
		     -excludeGroups=>[1,2,7],
		     -label=>WebGUI::International::get(605),
		     -size=>5,
		     -multiple=>1
	   );
	}else{
	   $f->hidden("status","Active");
	}
	my $options;
	foreach (@{$session{config}{authMethods}}) {
		$options->{$_} = $_;
	}
	$f->select(
	            -name=>"authMethod",
				-options=>$options,
				-label=>WebGUI::International::get(164),
				-value=>[$session{setting}{authMethod}],
				-extras=>"onChange=\"active=operateHidden(this.options[this.selectedIndex].value,active)\""
			  );
	my $jscript = '<script language="JavaScript">';
	foreach (@{$session{config}{authMethods}}) {
		my $authInstance = WebGUI::Operation::Auth::getInstance($_,1);
		$f->raw('<tr id="'.$_.'"><td colspan="2" align="center"><table border=0 cellspacing=0 cellpadding=0>'.$authInstance->addUserForm("new").'<tr><td width="170">&nbsp;</td><td>&nbsp;</td></tr></table></td></tr>');
		$jscript .= "document.getElementById(\"$_\").style.display='".(($_ eq $session{setting}{authMethod})?"":"none")."';";
	}
	$jscript .= "</script>";	
	$f->submit;
	$output .= $f->print;
	$output .= $jscript;
    	return _submenu($output,'163',"user add/edit");
}

#-------------------------------------------------------------------
sub www_addUserSave {
    my (@groups, $uid, $u);
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3) || WebGUI::Grouping::isInGroup(11));
	($uid) = WebGUI::SQL->quickArray("select userId from users where username=".quote($session{form}{username}));
	return www_addUser if ($uid);
	
	$u = WebGUI::User->new("new");
	$u->username($session{form}{username});
	foreach (@{$session{config}{authMethods}}) {
	   my $authInstance = WebGUI::Operation::Auth::getInstance($_,$u->userId);
	   $authInstance->addUserFormSave;
	}
	$session{form}{uid}=$u->userId;
	$u->status($session{form}{status});
	$u->authMethod($session{form}{authMethod});
    @groups = $session{cgi}->param('groups');
	$u->addToGroups(\@groups);
	$u->profileField("email",$session{form}{email});
    return _submenu(WebGUI::International::get(978)) if(!WebGUI::Grouping::isInGroup(3));
	return www_editUser();
}

#-------------------------------------------------------------------
sub www_addUserToGroupSave {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
        my (@groups, $u);
        @groups = $session{cgi}->param('groups');
	$u = WebGUI::User->new($session{form}{uid});
	$u->addToGroups(\@groups);
        return www_editUserGroup();
}

#-------------------------------------------------------------------
sub www_becomeUser {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
        WebGUI::Session::end($session{var}{sessionId});
	WebGUI::Session::start($session{form}{uid});
	return "";
}

#-------------------------------------------------------------------
sub www_deleteGrouping {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
	if (($session{user}{userId} == $session{form}{uid} || $session{form}{uid} == 3) && $session{form}{gid} == 3) {
		return _submenu(WebGUI::Privilege::vitalComponent());
        }
        my @users = $session{cgi}->param('uid');
	my @groups = $session{cgi}->param("gid");
	foreach my $user (@users) {
		my $u = WebGUI::User->new($user);
		$u->deleteFromGroups(\@groups);
	}
	if ($session{form}{return} eq "manageUsersInGroup") {
		return WebGUI::Operation::Group::www_manageUsersInGroup();
	}
	return www_editUserGroup(); 
}

#-------------------------------------------------------------------
sub www_deleteUser {
        my ($output);
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
        if ($session{form}{uid} == 1 || $session{form}{uid} == 3) {
		return _submenu(WebGUI::Privilege::vitalComponent());
        } else {
                $output .= WebGUI::International::get(167).'<p>';
                $output .= '<div align="center"><a href="'.WebGUI::URL::page('op=deleteUserConfirm&uid='.$session{form}{uid}).
			'">'.WebGUI::International::get(44).'</a>';
                $output .= '&nbsp;&nbsp;&nbsp;&nbsp;<a href="'.WebGUI::URL::page('op=listUsers').'">'.
			WebGUI::International::get(45).'</a></div>'; 
		return _submenu($output,'42',"user delete");
        }
}

#-------------------------------------------------------------------
sub www_deleteUserConfirm {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
	my ($u);
        if ($session{form}{uid} == 1 || $session{form}{uid} == 3) {
	   return WebGUI::Privilege::vitalComponent();
    } else {
	   $u = WebGUI::User->new($session{form}{uid});
	   $u->delete;
       return www_listUsers();
    }
}

#-------------------------------------------------------------------
sub www_editGrouping {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
	my $f = WebGUI::HTMLForm->new;
        $f->hidden("op","editGroupingSave");
        $f->hidden("uid",$session{form}{uid});
        $f->hidden("gid",$session{form}{gid});
	my $u = WebGUI::User->new($session{form}{uid});
	my $g = WebGUI::Group->new($session{form}{gid});
        $f->readOnly($u->username,WebGUI::International::get(50));
        $f->readOnly($g->name,WebGUI::International::get(84));
	$f->date("expireDate",WebGUI::International::get(369),WebGUI::Grouping::userGroupExpireDate($session{form}{uid},$session{form}{gid}));
	$f->yesNo(
		-name=>"groupAdmin",
		-label=>WebGUI::International::get(977),
		-value=>WebGUI::Grouping::userGroupAdmin($session{form}{uid},$session{form}{gid})
		);
	$f->submit;
        return _submenu($f->print,'370');
}

#-------------------------------------------------------------------
sub www_editGroupingSave {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
        WebGUI::Grouping::userGroupExpireDate($session{form}{uid},$session{form}{gid},setToEpoch($session{form}{expireDate}));
        WebGUI::Grouping::userGroupAdmin($session{form}{uid},$session{form}{gid},$session{form}{groupAdmin});
        return www_editUserGroup();
}

#-------------------------------------------------------------------
sub www_editUser {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
	my ($output, $f, $u, $cmd, $html, %status);
	$u = WebGUI::User->new($session{form}{uid});
	WebGUI::Style::setScript($session{config}{extrasURL}."/swapLayers.js", {language=>"JavaScript"});
	$output .= '<script language="JavaScript" > var active="'.$u->authMethod.'"; </script>';
	$f = WebGUI::HTMLForm->new;
    $f->hidden("op","editUserSave");
    $f->hidden("uid",$session{form}{uid});
    $f->raw('<tr><td width="170">&nbsp;</td><td>&nbsp;</td></tr>');
	$f->readOnly($session{form}{uid},WebGUI::International::get(378));
    $f->readOnly($u->karma,WebGUI::International::get(537)) if ($session{setting}{useKarma});
    $f->readOnly(epochToHuman($u->dateCreated,"%z"),WebGUI::International::get(453));
    $f->readOnly(epochToHuman($u->lastUpdated,"%z"),WebGUI::International::get(454));
    $f->text("username",WebGUI::International::get(50),$u->username);
	tie %status, 'Tie::IxHash';
	%status = (
		Active		=>WebGUI::International::get(817),
		Deactivated	=>WebGUI::International::get(818),
		Selfdestructed	=>WebGUI::International::get(819)
		);
	if ($u->userId == $session{user}{userId}) {
		$f->hidden("status",$u->status);
	} else {
		$f->select("status",\%status,WebGUI::International::get(816),[$u->status]);
	}
	
	my $options;
	foreach (@{$session{config}{authMethods}}) {
		$options->{$_} = $_;
	}
	$f->select(
	            -name=>"authMethod",
				-options=>$options,
				-label=>WebGUI::International::get(164),
				-value=>[$u->authMethod],
				-extras=>"onChange=\"active=operateHidden(this.options[this.selectedIndex].value,active)\""
			  );
	my $jscript = '<script language="JavaScript">';
	foreach (@{$session{config}{authMethods}}) {
		my $authInstance = WebGUI::Operation::Auth::getInstance($_,$u->userId);
		$f->raw('<tr id="'.$_.'"><td colspan="2" align="center"><table>'.$authInstance->editUserForm.'<tr><td width="170">&nbsp;</td><td>&nbsp;</td></tr></table></td></tr>');
		$jscript .= "document.getElementById(\"$_\").style.display='".(($_ eq $u->authMethod)?"":"none")."';";
	}
	$jscript .= "</script>";	    
	$f->submit;
	$output .= $f->print;
	$output .= $jscript;
	return _submenu($output,'168',"user add/edit");
}

#-------------------------------------------------------------------
sub www_editUserSave {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
    my ($error, $uid, $u);
	($uid) = WebGUI::SQL->quickArray("select userId from users where username=".quote($session{form}{username}));
    
	if ($uid == $session{form}{uid} || $uid < 1) {
	   $u = WebGUI::User->new($session{form}{uid});
	   $u->username($session{form}{username});
	   $u->authMethod($session{form}{authMethod});
	   $u->status($session{form}{status});
	   foreach (@{$session{config}{authMethods}}) {
	      my $authInstance = WebGUI::Operation::Auth::getInstance($_,$u->userId);
	      $authInstance->editUserFormSave;
       }
	} else {
       $error = '<ul><li>'.WebGUI::International::get(77).' '.$session{form}{username}.'Too or '.$session{form}{username}.'02</ul>';
	}
	return $error.www_editUser();
}

#-------------------------------------------------------------------
sub www_editUserGroup {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
	my %hash;
	tie %hash, 'Tie::CPHash';
        my $output .= WebGUI::Form::formHeader()
                .WebGUI::Form::hidden({
                        name=>"uid",
                        value=>$session{form}{uid}
                        })
                .WebGUI::Form::hidden({
                        name=>"op",
                        value=>"deleteGrouping"
                        });
	$output .= '<table><tr><td class="tableHeader"><input type="image" src="'
                .WebGUI::Icon::_getBaseURL().'delete.gif" border="0"></td><td class="tableHeader">'.WebGUI::International::get(84).
		'</td><td class="tableHeader">'.WebGUI::International::get(369).'</td></tr>';
	my $p = WebGUI::Paginator->new("op=editUserGroups&uid=".$session{form}{uid});
	$p->setDataByQuery("select groups.groupId,groups.groupName,groupings.expireDate 
		from groupings,groups where groupings.groupId=groups.groupId and groupings.userId=".quote($session{form}{uid})." and groups.isEditable > 0 order by groups.groupName");
	foreach my $row (@{$p->getPageData}) {
                $output .= '<tr><td>'
			.WebGUI::Form::checkbox({
                                name=>"gid",
                                value=>$row->{groupId}
                                })
			.deleteIcon('op=deleteGrouping&uid='.$session{form}{uid}.'&gid='.$row->{groupId})
                        .editIcon('op=editGrouping&uid='.$session{form}{uid}.'&gid='.$row->{groupId})
                        .'</td>';
                $output .= '<td class="tableData">'.$row->{groupName}.'</td>';
                $output .= '<td class="tableData">'.epochToHuman($row->{expireDate},"%z").'</td></tr>';
        }
        $output .= '</table>'.WebGUI::Form::formFooter();
	$output .= $p->getBarTraditional;
        $output .= '<p><h1>'.WebGUI::International::get(605).'</h1>';
	$output .= WebGUI::Operation::Group::getGroupSearchForm("editUserGroup",{uid=>$session{form}{uid}});
	my ($groupCount) = WebGUI::SQL->quickArray("select count(*) from users");
        return _submenu($output) unless ($session{form}{doit} || $groupCount < 250);
	my $f = WebGUI::HTMLForm->new;
        $f->hidden("op","addUserToGroupSave");
        $f->hidden("uid",$session{form}{uid});
        my $existingGroups = WebGUI::Grouping::getGroupsForUser($session{form}{uid});
        push(@$existingGroups,1); #visitors
        push(@$existingGroups,2); #registered users
        push(@$existingGroups,7); #everyone
	my %groups;
        tie %groups, "Tie::IxHash";
        my $sth = WebGUI::Operation::Group::doGroupSearch("op=editUserGroup&uid=".$session{form}{uid},0,$existingGroups);
        while (my $data = $sth->hashRef) {
                $groups{$data->{groupId}} = $data->{groupName};
        }
        $sth->finish;
        $f->selectList(
		-name=>"groups",
		-label=>WebGUI::International::get(605),
		-size=>7,
		-multiple=>1,
		-options=>\%groups
		);
        $f->submit;
	$output .= $f->print;
	return _submenu($output,'372');
}

#-------------------------------------------------------------------
sub www_editUserKarma {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
        my ($output, $f, $a, %user, %data, $method, $values, $category, $label, $default, $previousCategory);
        $f = WebGUI::HTMLForm->new;
        $f->hidden("op","editUserKarmaSave");
        $f->hidden("uid",$session{form}{uid});
	$f->integer("amount",WebGUI::International::get(556));
	$f->text("description",WebGUI::International::get(557));
        $f->submit;
        $output .= $f->print;
        return _submenu($output,'558',"karma using");
}

#-------------------------------------------------------------------
sub www_editUserKarmaSave {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
        my ($u);
        $u = WebGUI::User->new($session{form}{uid});
        $u->karma($session{form}{amount},$session{user}{username}." (".$session{user}{userId}.")",$session{form}{description});
        return www_editUser();
}

#-------------------------------------------------------------------
sub www_editUserProfile {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
        my ($output, $f, $a, %user, %data, $method, $values, $category, $label, $default, $previousCategory);
	tie %data, 'Tie::CPHash';
        $f = WebGUI::HTMLForm->new;
        $f->hidden("op","editUserProfileSave");
        $f->hidden("uid",$session{form}{uid});
	%user = WebGUI::SQL->buildHash("select fieldName,fieldData from userProfileData where userId=".quote($session{form}{uid}));
        $a = WebGUI::SQL->read("select * from userProfileField,userProfileCategory
                where userProfileField.profileCategoryId=userProfileCategory.profileCategoryId
                order by userProfileCategory.sequenceNumber,userProfileField.sequenceNumber");
        while(%data = $a->hash) {
              	$category = eval $data{categoryName};
                if ($category ne $previousCategory) {
                      	$f->raw('<tr><td colspan="2" class="tableHeader">'.$category.'</td></tr>');
                }
                $values = eval $data{dataValues};
                $method = $data{dataType};
                $label = eval $data{fieldLabel};
                if ($method eq "selectList" || $method eq "checkList" || $method eq "radioList") {
                        my $orderedValues = {};
                        tie %{$orderedValues}, 'Tie::IxHash';
                        foreach my $ov (sort keys %{$values}) {
                        	$orderedValues->{$ov} = $values->{$ov};
                        }
                        if ($session{form}{$data{fieldName}}) {
                      		$default = [$session{form}{$data{fieldName}}];
                        } elsif (exists $user{$data{fieldName}} && (defined($values->{$user{$data{fieldName}}}))) {
                                $default = [$user{$data{fieldName}}];
                        } else {
                                $default = eval $data{dataDefault};
                        }
                 	$f->$method(
				-name=>$data{fieldName},
				-options=>$orderedValues,
				-label=>$label,
				-value=>$default
				);
                } elsif ($method) {
			if ($session{form}{$data{fieldName}}) {
                        	$default = $session{form}{$data{fieldName}};
                        } elsif (exists $user{$data{fieldName}}) {
                                $default = $user{$data{fieldName}};
                        } else {
                                $default = eval $data{dataDefault};
                        }
                        $f->$method(
				-name=>$data{fieldName},
				-label=>$label,
				-value=>$default
				);
                }
                $previousCategory = $category;
        }
        $a->finish;
        $f->submit;
        $output .= $f->print;
	return _submenu($output,'455',"user profile edit");
}

#-------------------------------------------------------------------
sub www_editUserProfileSave {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
        my ($a, %field, $u);
      	tie %field, 'Tie::CPHash';
        $u = WebGUI::User->new($session{form}{uid});
      	$a = WebGUI::SQL->read("select fieldName,dataType from userProfileField");
      	while (%field = $a->hash) {
               	$u->profileField($field{fieldName},WebGUI::FormProcessor::process($field{fieldName},$field{dataType}));
       	}
       	$a->finish;
        return www_editUserProfile();
}

#-------------------------------------------------------------------
sub www_listUsers {
	return WebGUI::Privilege::adminOnly() unless (WebGUI::Grouping::isInGroup(3));
	my %status;
	my $output = getUserSearchForm("listUsers");
	my ($userCount) = WebGUI::SQL->quickArray("select count(*) from users");
	return _submenu($output) unless ($session{form}{doit} || $userCount<250);
	tie %status, 'Tie::IxHash';
	%status = (
		Active		=> WebGUI::International::get(817),
		Deactivated	=> WebGUI::International::get(818),
		Selfdestructed	=> WebGUI::International::get(819)
	);
        $output .= '<table border=1 cellpadding=5 cellspacing=0 align="center">';
        $output .= '<tr>
                <td class="tableHeader">'.WebGUI::International::get(816).'</td>
                <td class="tableHeader">'.WebGUI::International::get(50).'</td>
                <td class="tableHeader">'.WebGUI::International::get(56).'</td>
                <td class="tableHeader">'.WebGUI::International::get(453).'</td>
                <td class="tableHeader">'.WebGUI::International::get(454).'</td>
                <td class="tableHeader">'.WebGUI::International::get(429).'</td>
                <td class="tableHeader">'.WebGUI::International::get(434).'</td>
		</tr>';
	my $p = doUserSearch("listUsers",1);
	foreach my $data (@{$p->getPageData}) {
		$output .= '<tr class="tableData">';
		$output .= '<td>'.$status{$data->{status}}.'</td>';
		$output .= '<td><a href="'.WebGUI::URL::page('op=editUser&uid='.$data->{userId})
			.'">'.$data->{username}.'</a></td>';
		$output .= '<td class="tableData">'.$data->{email}.'</td>';
		$output .= '<td class="tableData">'.epochToHuman($data->{dateCreated},"%z").'</td>';
		$output .= '<td class="tableData">'.epochToHuman($data->{lastUpdated},"%z").'</td>';
		my ($lastLoginStatus, $lastLogin) = WebGUI::SQL->quickArray("select status,timeStamp from userLoginLog where 
                        userId='$data->{userId}' order by timeStamp DESC");
                if ($lastLogin) {
                        $output .= '<td class="tableData">'.epochToHuman($lastLogin).'</td>';
                } else {
                        $output .= '<td class="tableData"> - </td>';
                }
                if ($lastLoginStatus) {
                        $output .= '<td class="tableData">'.$lastLoginStatus.'</td>';
                } else {
                        $output .= '<td class="tableData"> - </td>';
                }
		$output .= '</tr>';
	}
        $output .= '</table>';
        $output .= $p->getBarTraditional;
	return _submenu($output,undef,"users manage");
}

1;

