// Code your design here
`timescale 1ns / 1ps
 
module i2c_master( input clk, rst , newd,
input [6:0] addr,
input op,
inout sda,
output scl,
input [7:0] din,
output [7:0] dout,
output reg busy, ack_err, done
);
 
reg scl_t = 0;
reg sda_t = 0;
 
parameter sys_freq = 40000000; //40 MHz
parameter i2c_freq = 100000;  //// 100k
 
 
parameter clk_count4 = (sys_freq/i2c_freq);
parameter clk_count1 = clk_count4/4; 
 
integer count1 = 0;
reg i2c_clk = 0;
 

reg [1:0] pulse = 0;

  always @(posedge clk) begin
    if (rst) begin
      count_1 <=0;
      pulse <=0;
    end
      else if(busy==1'b0) begin
        count1 <=0;
        pulse <= 0;
      end
      else if(count1 == clk_count1*1-1) begin
        count1 <=count1+1;
        pulse <= 1;
      end
      else if(count1 == clk_count1*2-1) begin
        count1 <=count1+1;
        pulse <= 2;
      end
      else if(count1 == clk_count1*3-1) begin
        count1 <=count1+1;
        pulse <= 3;
      end
      else if(count1 == clk_count1*4-1) begin
        count1 <= 0;
        pulse <= 0;
      end
      else begin
        count1 <=count1+1;
      end
    end
  end

reg [3:0] bitcount = 0;
reg [7:0] data_addr   = 0, data_tx = 0;
reg r_ack = 0;
reg [7:0] rx_data = 0;
reg sda_en = 0;
 
 
typedef enum logic [3:0] {idle = 0, start = 1, write_addr = 2, ack_1 = 3, write_data = 4, read_data = 5, stop = 6, ack_2 =7, master_ack = 8} state_type;
state_type state = idle;

  always @(posedge clk) begin
    if (rst) begin
    state <=idle;
    sda_t <=1'b1;
    scl_t <=1'b1;
    busy <= 1'b0;
    done <= 1'b0;
    ack_err <= 1'b0;
    data_addr <= 1'b0;
    data_tx <=1'b0;
    bitcount <= 1'b0;
    end
    else begin

      case(state)
       
 		idle: begin
          done <= 1'b0;
          if(newd) begin
            state <= start;
            data_addr <= {addr,op};
            data_tx <= din;
            ack_err <=1'b0;
            busy <=1'b1;
          end
          else begin
            state <= idle;
            busy <= 1'b0;
            data_addr <= 0;
            data_tx <= 0;
            ack_err <=1'b0;
          end
        end
		
	   start: begin
         
         case(pulse) 
           0: begin
             scl_t <= 1;
             sda_t <= 1;
           end
           1: begin
             scl_t <= 1;
             sda_t <= 1;
           end
           2: begin
             scl_t <= 1;
             sda_t <= 0;
 			 
           end
           3: begin
             scl_t <= 1;
             sda_t <= 0;
           end
		
         endcase

         if (count1 == clk_count1*4 -1) begin
           state <= write_addr;
           scl_t <=1'b0;
         end
         else begin
           state <= start;
         end
         
       end
        
        write_addr: begin
          	sda_en <= 1;
          	if(bitcount <=7) begin    
         		case(pulse) 
           		    0: begin
             		scl_t <= 0;
             		sda_t <= 0;
           		    end
           			1: begin
             		scl_t <= 0;
             		sda_t <= data_addr[7-bitcount];
           		    end
           			2: begin
             		scl_t <= 1; 
           			end
           			3: begin
             		scl_t <= 1;
           			end
                endcase
            	if(count1 == clk_count1*4-1) begin
            	  bitcount <= bit_count + 1;
            	  state <= write_addr;
                  scl_t <= 1'b0;
          	    end
                else state <= write_addr;
          end
          else begin
            bitcount <= 0;
            state <= ack_1;
            sda_en <= 0; 
          end
        end
		
        ack_1:begin
          sda_en <= 0;
          case(pulse) 
           0: begin
             scl_t <= 0;
             sda_t <= 1;
           end
           1: begin
             scl_t <= 0;
             sda_t <= 1;
           end
           2: begin
             scl_t <= 1;
             sda_t <= 1'b0;
             r_ack <= sda;
 			 
           end
           3: begin
             scl_t <= 1;
           end
           endcase
            
            if(count1 == clk_count1*4-1) begin
              if(r_ack == 0 && data_addr[0] == 1) begin //read from slave
                 state <= read_data;
                 sda_t <=1;
                 sda_en <=0; 
                 bitcount <=0;
              end
              else if (r_ack == 0 && data_addr[0] == 0) begin //write to slave
                 state <= write_data;
                 sda_t <=0;
                 sda_en<=1; 
              end
              else begin
                 state <=stop;
                 ack_err <=1;
                 sda_en<=1; 
              end
              
            end
            else begin
              state <= ack_1;
            end
		
         end
        
        write_data: begin
          	if(bitcount <=7) begin    
         		case(pulse) 
           		    0: begin
             		scl_t <= 0;
             		sda_t <= 0;
           		    end
           			1: begin
             		scl_t <= 0;
             		sda_t <= data_tx[7-bitcount];
           		    end
           			2: begin
             		scl_t <= 1; 
           			end
           			3: begin
             		scl_t <= 1;
           			end
                endcase
            	if(count1 == clk_count1*4-1) begin
            	  bitcount <= bit_count + 1;
            	  state <= write_data;
                  scl_t <= 1'b0;
          	    end
                else state <= write_data;
          end
          else begin
            bitcount <= 0;
            state <= ack_2;
            sda_en <= 0; 
          end
        end
        
        ack_2:begin
          sda_en <= 0;
          case(pulse) 
           0: begin
             scl_t <= 0;
             sda_t <= 1;
           end
           1: begin
             scl_t <= 0;
             sda_t <= 1;
           end
           2: begin
             scl_t <= 1;
             sda_t <= 1'b0;
             r_ack <= sda;
 			 
           end
           3: begin
             scl_t <= 1;
           end
           endcase
            
            if(count1 == clk_count1*4-1) begin
              sda_t <= 0;
              sda_en<=1;
              if(r_ack == 0 ) begin 
                 state <= stop;
                 ack_err <= 1'b0;   
              end
              else begin
                 state <=stop;
                 ack_err <=1; 
              end
            else begin
               state <= ack_2;
            end
              
         end
          
          read_data: begin
     
          	if(bitcount <=7) begin    
         		case(pulse) 
           		    0: begin
             		scl_t <= 0;
             		sda_t <= 0;
           		    end
           			1: begin
             		scl_t <= 0;
                    sda_t <= 0;
           		    end
           			2: begin
             		scl_t <= 1; 
                    rx_data[7:0] <= (count1 == 200) ? {rx_data[6:0],sda} : rx_data;
           			end
           			3: begin
             		scl_t <= 1;
           			end
                endcase
            	if(count1 == clk_count1*4-1) begin
            	  bitcount <= bit_count + 1;
            	  state <= read_data;
                  scl_t <= 1'b0;
          	    end
                else state <= read_data;
          end
          else begin
            bitcount <= 0;
            state <= master_ack;
            sda_en <= 1; 
          end
         end
          
          master_ack: begin
             sda_en <= 1;
          case(pulse) 
           0: begin
             scl_t <= 0;
             sda_t <= 1;
           end
           1: begin
             scl_t <= 0;
             sda_t <= 1;
           end
           2: begin
             scl_t <= 1;
             sda_t <= 1'b1; 
           end
           3: begin
             scl_t <= 1;
             sda_t <= 1'b1; 
           end
           endcase
            
            if(count1 == clk_count1*4-1) begin
              sda_t <= 0;
              state <=stop;
              sda_en <= 1'b1;
              end
            else begin
               state <= master_ack;
            end
              
          end
          
          stop: begin
            case(pulse) 
           0: begin
             scl_t <= 1;
             sda_t <= 0;
           end
           1: begin
             scl_t <= 1;
             sda_t <= 0;
           end
           2: begin
             scl_t <= 1;
             sda_t <= 1;
 			 
           end
           3: begin
             scl_t <= 1;
             sda_t <= 1;
           end
		
         endcase

         if (count1 == clk_count1*4 -1) begin
           state <= idle;
           busy <=1'b0;
           sda_en <= 1'b1;
           done <=1'b1;
           scl_t <=1'b0;
         end
         else begin
           state <= stop;
         end
         end

       default : state <= idle;

      endcase

    end
   
  end




  assign sda = (sda_en==1) ? (sda_t==0) ? 1'b0 : 1'b1 : 1'bz;
  assign scl = scl_t;
  assign dout <= rx_data;
endmodule
        
module i2c_Slave(
input scl,clk,rst,
inout sda,
output reg ack_err, done
    );
  
typedef enum logic [3:0] {idle = 0, read_addr = 1, send_ack1 = 2, send_data = 3, master_ack = 4, read_data = 5, send_ack2 = 6, wait_p = 7, detect_stop = 8} state_type;
state_type state = idle; 
 
reg [7:0] mem [128];
reg [7:0] r_addr;
reg [6:0] addr;
reg r_mem = 0;
reg w_mem = 0;
reg [7:0] dout;
reg [7:0] din;
reg sda_t;
reg sda_en;
reg [3:0] bitcnt = 0;

  always@(posedge clk) begin
    if(rst) begin
      for(int i = 0 ; i < 128; i++)
        begin
        mem[i] = i;
        end
      dout <= 8'h0;
  end
    else if (r_mem == 1'b1) begin
      dout <= mem[addr];
   end
    else if (w_mem == 1'b1) begin
      mem[addr] <= din;
   end 
   
  end
  
parameter sys_freq = 40000000;
parameter i2c_freq = 100000;
 
 
parameter clk_count4 = (sys_freq/i2c_freq);
parameter clk_count1 = clk_count4/4;
integer count1 = 0;
reg i2c_clk = 0;

reg [1:0] pulse = 0;
reg busy;

  always @(posedge clk) begin
      if (rst) begin
      pulse <= 0;
      count1 <= 0;
      end
      else if(busy == 1'b0 ) begin
      count1 <=202; // synchronizing with master's count1 and pulse
      pulse <=2;
      end
      else if(count1  == clk_count1 - 1) begin
       pulse <= 1;
       count1 <= count1 + 1;
       end
      else if(count1  == clk_count1*2 - 1)  begin
       pulse <= 2;
       count1 <= count1 + 1;
       end
      else if(count1  == clk_count1*3 - 1) begin
       pulse <= 3;
       count1 <= count1 + 1;
       end
      else if(count1  == clk_count1*4 - 1) begin
       pulse <= 0;
       count1 <= 0;
       end
      else begin
       count1 <= count1 + 1;
      end
 end
  
reg scl_t;
wire start;
always@(posedge clk)
begin
scl_t <= scl;
end
 
assign start = ~scl & scl_t; 
 
reg r_ack;
 
always@(posedge clk)
begin
if(rst)
 begin
   bitcnt <= 0;
                  state  <= idle;
                  r_addr <= 7'b0000000;
                  sda_en <= 1'b0;
                  sda_t <= 1'b0;
                  addr  <= 0;
                  r_mem <= 0;
                  din   <= 8'h00; 
                  ack_err <= 0;
                  done    <= 1'b0;
                  busy <= 1'b0;
 end
  else begin
    case(state)
      idle: begin
        if(scl==1 && sda==0) begin
          state <=wait_p;
          busy <= 1'b1;
        else begin
          state <= idle;
        end
      end
      
      wait_p: begin
        if(pulse==2'b11 && count1==399) begin
          state <=read_addr;
        end
        else begin
          state <=wait_p;
        end
      end
        
      read_addr: begin
        sda_en <= 1'b0;
        if(bitcnt <=7) begin
        case(pulse)
          pulse 0: begin          
          end
          pulse 1: begin         
          end
          pulse 2: begin
            r_addr <= (count1==200) ? {r_addr[6:0],sda} :0;           
          end
          pulse 3: begin        
          end
          endcase

          	if(count1 == clk_count*4-1) begin
              bitcnt <= bitcnt +1;
              state <= ; 
          	end
            else begin
            state <= read_addr; 
            end
        else begin
          bitcnt <= 0;
          state <= send_ack1;
          sda_en <=1;
          addr <= r_addr[7:1];
        end
      end

      send_ack1: begin
        case(pulse)
          pulse 0: begin 
            sda_t <= 0;
          end
          pulse 1: begin         
          end
          pulse 2: begin  
          end
          pulse 3: begin        
          end
          endcase
            if(count1 == clk_count*4-1) begin
              if(r_addr[0] == 1) begin                
                state <= send_data;
                r_mem <=1;
              end
              else begin
                sda_en <=0;
                state <= read_data;
                r_mem <=0;
              end
          	end
            else begin
              state <= send_ack1; 
            end
      end

      read_data: begin
        sda_en <= 1'b0;
        if(bitcnt <=7) begin
        case(pulse)
          pulse 0: begin          
          end
          pulse 1: begin         
          end
          pulse 2: begin
            din <= (count1==200) ? {din[6:0],sda} :0;           
          end
          pulse 3: begin        
          end
          endcase

          	if(count1 == clk_count*4-1) begin
              bitcnt <= bitcnt +1;
              state <= read_data; 
          	end
            else begin
            state <= read_data; 
            end
        else begin
          bitcnt <= 0;
          state <= send_ack2;
          sda_en <=1;
          w_mem  <= 1'b1;
        end
      end

      send_ack2: begin
        case(pulse)
          pulse 0: begin 
           sda_t <= 0;
          end
          pulse 1: begin  
            w_mem <= 1'b0; 
          end
          pulse 2: begin  
          end
          pulse 3: begin        
          end
          endcase
            if(count1 == clk_count*4-1) begin
               state <= detect_stop;
               sda_en <=0;
              end
              else begin
                state <= send_ack2;
              end
      end
        
      send_data: begin
        if(bitcnt <=7) begin
          r_mem  <= 1'b0;
        case(pulse)
          pulse 0: begin          
          end
          pulse 1: begin 
            sda_t <= (count1 == 100) ? dout[7 - bitcnt] : sda_t; 
          end
          pulse 2: begin          
          end
          pulse 3: begin        
          end
          endcase

          	if(count1 == clk_count*4-1) begin
              bitcnt <= bitcnt +1;
              state <= send_data; 
          	end
            else begin
              state <= send_data; 
            end
        else begin
          bitcnt <= 0;
          state <= master_ack;
          sda_en <=0;
        end
      end

      master_ack: begin
        case(pulse)
          pulse 0: begin 
          end
          pulse 1: begin  
          end
          pulse 2: begin
            r_ack <= (count1 == 200) ? sda : r_ack;
          end
          pulse 3: begin        
          end
          endcase
              if(count1 == clk_count*4-1) begin
                if(r_ack <= 1'b1)begin
                 state <= detect_stop;
                  ack_err <=0;
                  sda_en <=0;
                end
                else begin
                  state <= detect_stop;
                  ack_err <=1;
                  sda_en <=0;
                end
              end
              else begin
                state <= master_ack;
              end
      end
      end

      detect_stop:begin
        if(pulse == 2'b11 && count1 == 399) begin
           state <= idle;
           busy <= 1'b0;
           done <= 1'b1;
        end
        else state <= detect_stop;
      end

      default: state <= idle;

      endcase
    end   
  end
        
 assign sda = (sda_en == 1'b1) ? sda_t : 1'bz;
       
        endmodule
  
  
