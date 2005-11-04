package WebGUI::Asset::Post::Thread;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2005 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use WebGUI::Asset::Template;
use WebGUI::Asset::Post;
use WebGUI::DateTime;
use WebGUI::Grouping;
use WebGUI::International;
use WebGUI::MessageLog;
use WebGUI::Paginator;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::Utility;

our @ISA = qw(WebGUI::Asset::Post);


#-------------------------------------------------------------------
sub canReply {
	my $self = shift;
	return !$self->isLocked && $self->getParent->get("allowReplies") && $self->getParent->canPost;
}

#-------------------------------------------------------------------
sub canSubscribe {
	my $self = shift;
	return ($session{user}{userId} ne "1" && $self->canView);
}

#-------------------------------------------------------------------
sub createSubscriptionGroup {
	my $self = shift;
	return if ($self->get("subscriptionGroupId"));
	my $group = WebGUI::Group->new("new");
	$group->name($self->getId);
	$group->description("The group to store subscriptions for the thread ".$self->getId);
	$group->isEditable(0);
	$group->showInForms(0);
	$group->deleteGroups(['3']); # admins don't want to be auto subscribed to this thing
	$self->update({
		subscriptionGroupId=>$group->groupId
		});
}

#-------------------------------------------------------------------

=head2 decrementReplies ( )

Deccrements this reply counter.

=cut

sub decrementReplies {
        my $self = shift;
	$self->update({replies=>$self->get("replies")-1});
	$self->getParent->decrementReplies;
}

#-------------------------------------------------------------------
sub definition {
	my $class = shift;
        my $definition = shift;
        push(@{$definition}, {
		assetName=>WebGUI::International::get('assetName',"Asset_Thread"),
		icon=>'thread.gif',
                tableName=>'Thread',
                className=>'WebGUI::Asset::Post::Thread',
                properties=>{
			subscriptionGroupId => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				},
			replies => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				},
			isSticky => {
				fieldType=>"yesNo",
				defaultValue=>0
				},
			isLocked => {
				fieldType=>"yesNo",
				defaultValue=>0
				},
			lastPostId => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				},
			lastPostDate => {
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				}
			},
		});
        return $class->SUPER::definition($definition);
}

#-------------------------------------------------------------------

sub DESTROY {
	my $self = shift;
	return unless defined $self;
	$self->{_next}->DESTROY if (defined $self->{_next});
	$self->{_previous}->DESTROY if (defined $self->{_previous});
	$self->SUPER::DESTROY;
}



#-------------------------------------------------------------------
sub getLastPost {
	my $self = shift;
	my $lastPostId = $self->get("lastPostId");
	my $lastPost;
	if ($lastPostId) {
		$lastPost = WebGUI::Asset::Post->new($lastPostId);
	}
	return $lastPost if (defined $lastPost);
	return $self;	
}

#-------------------------------------------------------------------

=head2 getLayoutUrl ( layout )

Formats the url to change the layout of a thread.

=head3 layout

A string indicating the type of layout to use. Can be flat or nested.

=cut

sub getLayoutUrl {
	my $self = shift;
	my $layout = shift;
	return $session{asset}->getUrl("layout=".$layout.'#id'.$session{asset}->getId) if (exists $session{asset});
	return $self->getUrl("layout=".$layout);
}

#-------------------------------------------------------------------

=head2 getLockUrl ( )

Formats the url to lock a thread.

=cut

sub getLockUrl {
	my $self = shift;
	$self->getUrl("func=lock");
}


#-------------------------------------------------------------------

=head2 getNextThread ( )

Returns a thread object for the next (newer) thread in the same forum.

=cut

sub getNextThread {
	my $self = shift;
        unless (defined $self->{_next}) {
		my $sortBy = $self->getParent->getValue("sortBy");
		my ($id, $class, $version) = WebGUI::SQL->quickArray("
				select asset.assetId,asset.className,max(assetData.revisionDate)
				from Thread
				left join asset on asset.assetId=Thread.assetId 
				left join assetData on assetData.assetId=Thread.assetId and assetData.revisionDate=Thread.revisionDate
				left join Post on Post.assetId=assetData.assetId and assetData.revisionDate=Post.revisionDate
				where asset.parentId=".quote($self->get("parentId"))." 
					and asset.state='published' 
					and asset.className='WebGUI::Asset::Post::Thread'
					and ".$sortBy.">".quote($self->get($sortBy))." 
					and (
						assetData.status in ('approved','archived')
						 or assetData.tagId=".quote($session{scratch}{versionTag})."
						or (assetData.ownerUserId=".quote($session{user}{userId})." and assetData.ownerUserId<>'1')
						)
				group by assetData.assetId
				order by ".$sortBy." asc 
				",WebGUI::SQL->getSlave);
		$self->{_next} = WebGUI::Asset->new($id,$class,$version);
	#	delete $self->{_next} unless ($self->{_next}->{_properties}{className} =~ /Thread/);
	};
	return $self->{_next};
}



#-------------------------------------------------------------------

=head2 getPreviousThread ( )

Returns a thread object for the previous (older) thread in the same forum.

=cut

sub getPreviousThread {
	my $self = shift;
        unless (defined $self->{_previous}) {
		my $sortBy = $self->getParent->getValue("sortBy");
		my ($id, $class, $version) = WebGUI::SQL->quickArray("
				select asset.assetId,asset.className,max(assetData.revisionDate)
				from Thread
				left join asset on asset.assetId=Thread.assetId 
				left join assetData on assetData.assetId=Thread.assetId and assetData.revisionDate=Thread.revisionDate
				left join Post on Post.assetId=assetData.assetId and assetData.revisionDate=Post.revisionDate
				where asset.parentId=".quote($self->get("parentId"))." 
					and asset.state='published' 
					and asset.className='WebGUI::Asset::Post::Thread'
					and ".$sortBy."<".quote($self->get($sortBy))." 
					and (
						assetData.status in ('approved','archived')
						 or assetData.tagId=".quote($session{scratch}{versionTag})."
						or (assetData.ownerUserId=".quote($session{user}{userId})." and assetData.ownerUserId<>'1')
						)
				group by assetData.assetId
				order by ".$sortBy." desc, assetData.revisionDate desc ",WebGUI::SQL->getSlave);
		$self->{_previous} = WebGUI::Asset::Post::Thread->new($id,$class,$version);
	#	delete $self->{_previous} unless ($self->{_previous}->{_properties}{className} =~ /Thread/);
	};
	return $self->{_previous};
}


#-------------------------------------------------------------------

=head2 getStickUrl ( )

Formats the url to make a thread sticky.

=cut

sub getStickUrl {
	my $self = shift;
	return $self->getUrl("func=stick");
}

#-------------------------------------------------------------------
id
=head2 getSubscribeUrl (  )

Formats the url to subscribe to the thread

=cut

sub getSubscribeUrl {
	my $self = shift;
	return $self->getUrl("func=subscribe");
}


#-------------------------------------------------------------------
sub getThread {
	return shift;
}

#-------------------------------------------------------------------

=head2 getUnlockUrl ( )

Formats the url to unlock the thread

=cut

sub getUnlockUrl {
	my $self = shift;
	return $self->getUrl("func=unlock");
}


#-------------------------------------------------------------------

=head2 getUnstickUrl ( )

Formats the url to unstick the thread

=cut

sub getUnstickUrl {
	my $self = shift;
	return $self->getUrl("func=unstick");
}

#-------------------------------------------------------------------

=head2 getUnsubscribeUrl ( )

Formats the url to unsubscribe from the thread

=cut

sub getUnsubscribeUrl {
	my $self = shift;
	return $self->getUrl("func=unsubscribe");
}


#-------------------------------------------------------------------

=head2 isLocked ( )

Returns a boolean indicating whether this thread is locked from new posts and other edits.

=cut

sub isLocked {
        my ($self) = @_;
        return $self->get("isLocked");
}


#-------------------------------------------------------------------

=head2 incrementReplies ( lastPostDate, lastPostId )

Increments the replies counter for this thread.

=head3 lastPostDate

The date of the reply that caused the replies counter to be incremented.

=head3 lastPostId

The id of the reply that caused the replies counter to be incremented.

=cut

sub incrementReplies {
        my ($self, $dateOfReply, $replyId) = @_;
        $self->update({replies=>$self->get("replies")+1, lastPostId=>$replyId, lastPostDate=>$dateOfReply});
        $self->getParent->incrementReplies($dateOfReply,$replyId);
}

#-------------------------------------------------------------------

=head2 incrementViews ( )

Increments the views counter for this thread.

=cut

sub incrementViews {
        my ($self) = @_;
        $self->update({views=>$self->get("views")+1});
        $self->getParent->incrementViews;
}

#-------------------------------------------------------------------

=head2 isMarkedRead ( )

Returns a boolean indicating whether this thread is marked read for the user.

=cut

sub isMarkedRead {
        my $self = shift;
	return 1 if $self->isPoster;
      my ($isRead) = WebGUI::SQL->quickArray("select count(*) from Post_read where userId=".quote($session{user}{userId})." and threadId=".quote($self->getId)." and postId=".quote($self->get("lastPostId")));
        return $isRead;
}

#-------------------------------------------------------------------

=head2 isSticky ( )

Returns a boolean indicating whether this thread should be "stuck" a the top of the forum and not be sorted with the rest of the threads.

=cut

sub isSticky {
        my ($self) = @_;
        return $self->get("isSticky");
}


#-------------------------------------------------------------------

=head2 isSubscribed ( )

Returns a boolean indicating whether the user is subscribed to this thread.

=cut

sub isSubscribed {
	my $self = shift;
	return WebGUI::Grouping::isInGroup($self->get("subscriptionGroupId"));
}

#-------------------------------------------------------------------

=head2 lock ( )

Sets this thread to be locked from edits.

=cut

sub lock {
        my ($self) = @_;
        $self->update({isLocked=>1});
}


#-------------------------------------------------------------------
sub processPropertiesFromFormPost {
	my $self = shift;
	$self->SUPER::processPropertiesFromFormPost;	
	if ($self->get("subscriptionGroupId") eq "") {
		$self->createSubscriptionGroup;
	}
}


#-------------------------------------------------------------------

=head2 rate ( rating )

Stores a rating against this post.

=head3 rating

An integer between 1 and 5 (5 being best) to rate this post with.

=cut

sub rate {
	my $self = shift;
	my $rating = shift;
	unless ($self->hasRated) {
		WebGUI::SQL->write("insert into Post_rating (assetId,userId,ipAddress,dateOfRating,rating) values ("
			.quote($self->getId).", ".quote($session{user}{userId}).", ".quote($session{env}{REMOTE_ADDR}).",
		".WebGUI::DateTime::time().", ".quote($rating).")");
		my ($count) = WebGUI::SQL->quickArray("select count(*) from Post left join asset on Post.assetId=asset.assetId where Post.threadId=".quote($self->getId)." and Post.rating>0");
		$count = $count || 1;
		my ($sum) = WebGUI::SQL->quickArray("select sum(Post.rating) from Post left join asset on Post.assetId=asset.assetId where Post.threadId=".quote($self->getId)." and Post.rating>0");
		my $average = round($sum/$count);
		$self->update({rating=>$average});
		if ($session{setting}{useKarma}) {
			my $poster = WebGUI::User->new($self->get("ownerUserId"));
			$poster->karma($rating*$self->getParent->get("karmaRatingMultiplier"),"collaboration rating","someone rated post ".$self->getId);
			my $rater = WebGUI::User->new($session{user}{userId});
			$rater->karma(-$self->getParent->get("karmaSpentToRate"),"collaboration rating","spent karma to rate post ".$self->getId);
		}
		$self->getParent->recalculateRating;
	}
}


#-------------------------------------------------------------------

=head2 setLastPost ( id, date )

Sets the last reply of this thread.

=head3 id

The assetId of the most recent post.

=head3 date

The date of the most recent post.

=cut

sub setLastPost {
        my $self = shift;
        my $id = shift;
        my $date = shift;
        $self->update({lastPostId=>$id, lastPostDate=>$date});
        $self->getParent->setLastPost($id,$date);
}


#-------------------------------------------------------------------

=head2 setParent ( newParent ) 

We're overloading the setParent in Asset because we don't want threads to be able to be posted to anything other than other collaboration systems.

=head3 newParent 
        
An asset object to make the parent of this asset.

=cut

sub setParent {
        my $self = shift;
        my $newParent = shift;
        return 0 unless ($newParent->get("className") eq "WebGUI::Asset::Wobject::Collaboration");
        # specify the Asset package here directly because we don't want to use the ruls in WebGUI::Asset::Post, as they don't fit for Threads.
        return $self->WebGUI::Asset::setParent($newParent);
}  

#-------------------------------------------------------------------

=head2 setStatusApproved ( )

Sets the post to approved and sends any necessary notifications.

=cut

sub setStatusApproved {
	my $self = shift;
	$self->SUPER::setStatusApproved;
        $self->getParent->incrementThreads($self->get("dateUpdated"),$self->getId) unless ($self->isReply);
}


#-------------------------------------------------------------------

=head2 stick ( )

Makes this thread sticky.

=cut

sub stick {
        my ($self) = @_;
        $self->update({isSticky=>1});
}

#-------------------------------------------------------------------

=head2 subscribe (  )

Subscribes the user to this thread.

=cut

sub subscribe {
	my $self = shift;
	$self->createSubscriptionGroup;
  WebGUI::Cache->new("cspost_".$self->getId."_".$session{user}{userId}."_".$session{scratch}{discussionLayout}."_".$session{form}{pn})->delete;
  WebGUI::Grouping::addUsersToGroups([$session{user}{userId}],[$self->get("subscriptionGroupId")]);
}

#-------------------------------------------------------------------

=head2 trash

Moves thread to the trash and decrements reply counter on thread.

=cut

sub trash {
        my $self = shift;
        $self->SUPER::trash;
        $self->getParent->decrementThreads;
        if ($self->getParent->get("lastPostId") eq $self->getId) {
                my $parentLineage = $self->getThread->get("lineage");
                my ($id, $date) = WebGUI::SQL->quickArray("select Post.assetId, Post.dateSubmitted from Post, asset where asset.lineage like ".quote($parentLineage.'%')." and Post.assetId<>".quote($self->getId)." and Post.assetId=asset.assetId and asset.state='published' order by Post.dateSubmitted desc");
                $self->getParent->setLastPost('','') ? $self->getParent->setLastPost($id,$date) : $id;
        }
}


#-------------------------------------------------------------------

=head2 unlock ( )

Negates the lock method.

=cut

sub unlock {
        my ($self) = @_;
        $self->update({isLocked=>0});
}

#-------------------------------------------------------------------

=head2 unstick ( )

Negates the stick method.

=cut

sub unstick {
        my ($self) = @_;
        $self->update({isSticky=>0});
}

#-------------------------------------------------------------------

=head2 unsubscribe (  )

Negates the subscribe method.

=cut

sub unsubscribe {
	my $self = shift;
  WebGUI::Cache->new("cspost_".$self->getId."_".$session{user}{userId}."_".$session{scratch}{discussionLayout}."_".$session{form}{pn})->delete;
  WebGUI::Grouping::deleteUsersFromGroups([$session{user}{userId}],[$self->get("subscriptionGroupId")]);
}


#-------------------------------------------------------------------
sub view {
	my $self = shift;
        $self->markRead;
        $self->incrementViews unless ($session{form}{func} eq 'rate');
        WebGUI::Session::setScratch("discussionLayout",$session{form}{layout});
        my $var = $self->getTemplateVars;
	$self->getParent->appendTemplateLabels($var);

        $var->{'user.isVisitor'} = ($session{user}{userId} eq '1');
        $var->{'user.isModerator'} = $self->getParent->canModerate;
        $var->{'user.canPost'} = $self->getParent->canPost;
        $var->{'user.canReply'} = $self->canReply;
        $var->{'repliesAllowed'} = $self->getParent->get("allowReplies");

        $var->{'layout.nested.url'} = $self->getLayoutUrl("nested");
        $var->{'layout.flat.url'} = $self->getLayoutUrl("flat");
        my $layout = $session{scratch}{discussionLayout} || $session{user}{discussionLayout};
        $var->{'layout.isFlat'} = ($layout eq "flat");
        $var->{'layout.isNested'} = ($layout eq "nested" || !$var->{'layout.isFlat'});

        $var->{'user.isSubscribed'} = $self->isSubscribed;
        $var->{'subscribe.url'} = $self->getSubscribeUrl;
        $var->{'unsubscribe.url'} = $self->getUnsubscribeUrl;

        $var->{'isSticky'} = $self->isSticky;
        $var->{'stick.url'} = $self->getStickUrl;
        $var->{'unstick.url'} = $self->getUnstickUrl;

        $var->{'isLocked'} = $self->isLocked;
        $var->{'lock.url'} = $self->getLockUrl;
        $var->{'unlock.url'} = $self->getUnlockUrl;

        my $p = WebGUI::Paginator->new($self->getUrl,$self->getParent->get("postsPerPage"));
	my $sql = "select asset.assetId, asset.className, max(assetData.revisionDate) as revisionDate from asset 
		left join assetData on assetData.assetId=asset.assetId
		left join Post on Post.assetId=assetData.assetId and assetData.revisionDate=Post.revisionDate
		where asset.lineage like ".quote($self->get("lineage").'%')
		."	and asset.state='published'
			and (
				assetData.status in ('approved','archived')
						 or assetData.tagId=".quote($session{scratch}{versionTag});
	$sql .= "		or assetData.status='pending'" if ($self->getParent->canModerate);
	$sql .= "		or (assetData.ownerUserId=".quote($session{user}{userId})." and assetData.ownerUserId<>'1')
				)
		group by assetData.assetId
		order by ";
	if ($layout eq "flat") {
		$sql .= "Post.dateSubmitted";
	} else {
		$sql .= "asset.lineage";
	}
	my $currentPageUrl = $session{wguri};
	$currentPageUrl =~ s/^\///;
	$p->setDataByQuery($sql, undef, undef, undef, "url", $currentPageUrl);
	foreach my $dataSet (@{$p->getPageData()}) {
		next unless ($dataSet->{className} eq "WebGUI::Asset::Post" || $dataSet->{className} eq "WebGUI::Asset::Post::Thread"); #handle non posts!
		my $reply = WebGUI::Asset::Post->new($dataSet->{assetId}, $dataSet->{className}, $dataSet->{revisionDate});
		$reply->{_thread} = $self; # caching thread for better performance
		my %replyVars = %{$reply->getTemplateVars};
		$replyVars{isCurrent} = ($reply->get("url") eq $currentPageUrl);
		$replyVars{isThreadRoot} = $self->getId eq $reply->getId;
		$replyVars{depth} = $reply->getLineageLength - $self->getLineageLength;
		$replyVars{depthX10} = $replyVars{depth}*10;
        	my @depth_loop;
		#@{$replyVars{indent_loop}} = {};
        	for (my $i=0; $i<$replyVars{depth}; $i++) {
                	push(@{$replyVars{indent_loop}},{depth=>$i});
        	}
		push (@{$var->{post_loop}}, \%replyVars);
	}		
	$p->appendTemplateVars($var);
        $var->{'add.url'} = $self->getParent->getNewThreadUrl;
 
	my $previous = $self->getPreviousThread;
	$var->{"previous.url"} = $previous->getUrl if (defined $previous);
	my $next = $self->getNextThread;
	$var->{"next.url"} = $next->getUrl if (defined $next);

	$var->{"search.url"} = $self->getParent->getSearchUrl;
        $var->{"collaboration.url"} = $self->getThread->getParent->getUrl;
        $var->{'collaboration.title'} = $self->getParent->get("title");
        $var->{'collaboration.description'} = $self->getParent->get("description");

	return $self->processTemplate($var,$self->getParent->get("threadTemplateId"));
}


#-------------------------------------------------------------------

=head2 www_lock (  )

The web method to lock a thread.

=cut

sub www_lock {
	my $self = shift;
	$self->lock if $self->getParent->canModerate;
	return $self->www_view;
}

#-------------------------------------------------------------------

=head2 www_stick ( )

The web method to make a thread sticky.

=cut

sub www_stick {
	my $self = shift;
	$self->stick if $self->getParent->canModerate;
	return $self->www_view;
}

#-------------------------------------------------------------------

=head2 www_subscribe ( )

The web method to subscribe to a thread.

=cut

sub www_subscribe {
	my $self = shift;
	$self->subscribe if $self->canSubscribe;
	return $self->www_view;
}

#-------------------------------------------------------------------

=head2 www_unlock ( )

The web method to unlock a thread.

=cut

sub www_unlock {
	my $self = shift;
	$self->unlock if $self->getParent->canModerate;
	return $self->www_view;
}

#-------------------------------------------------------------------

=head2 www_unstick (  )

The web method to make a sticky thread normal again.

=cut

sub www_unstick {
	my $self = shift;
	$self->unstick if $self->getParent->canModerate;
	$self->www_view;
}

#-------------------------------------------------------------------

=head2 www_threadUnsubscribe ( )

The web method to unsubscribe from a thread.

=cut

sub www_unsubscribe {
	my $self = shift;
	$self->unsubscribe if $self->canSubscribe;
	return $self->www_view;
}

#-------------------------------------------------------------------
sub www_view {
	my $self = shift;
	my $postId = shift;
	return WebGUI::Privilege::noAccess() unless $self->canView;
	my $cache;
	my $output;
        my $useCache = (
		$session{form}{op} eq "" && 
		$session{form}{func} eq "" && 
		$session{form}{layout} eq "" && 
		(
			( $self->getParent->get("cacheTimeout") > 10 && $session{user}{userId} ne '1') || 
			( $self->getParent->get("cacheTimeoutVisitor") > 10 && $session{user}{userId} eq '1')
		) && 
		not $session{var}{adminOn}
	);
	if ($useCache) {
               	$cache = WebGUI::Cache->new("cspost_".($postId||$self->getId)."_".$session{user}{userId}."_".$session{scratch}{discussionLayout}."_".$session{form}{pn});
           	$output = $cache->get;
	}
	unless ($output) {
		$output = $self->getParent->processStyle($self->view);
		my $ttl;
		if ($session{user}{userId} eq '1') {
			$ttl = $self->getParent->get("cacheTimeoutVisitor");
		} else {
			$ttl = $self->getParent->get("cacheTimeout");
		}
		$cache->set($output, $ttl) if ($useCache);
	}
	return $output;
}


1;

