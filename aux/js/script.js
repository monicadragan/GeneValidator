function showDiv(toggle){
   var button = document.getElementById(toggle)
   if(button.style.display == "block"){
     button.style.display = "none";
   }
   else{
      button.style.display = "block";
   }
}

$(document).ready(function() { 
    $("#sortable_table").tablesorter( {sortList: [[0,0]]} ); 
}); 

$(function (){
	$( ".my_popover" ).popover();
});


$(".btn-block").css('height', $(".btn-block").parent('td').height());

$(".my-btn-success").css('height', 50);
document.getElementById('ana').style.height = 50+'px';

$(document).ready(function(){
	$('.table-fixed-header').fixedHeader();
});
